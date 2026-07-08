# Diff MIUR-vs-MIUR di un import adozioni (design 2026-07-08-miur-import-diff-design.md).
#
# Due fasi, perché il run ImportRun nasce DOPO lo swap di partizione:
#   calcola   — PRE-swap: partizione vecchia e staging convivono nel DB; il diff
#               (EXCEPT sulla class-key) finisce in TEMP tables sulla connessione.
#   persisti  — POST-swap: travasa le TEMP nelle tabelle vere, legate al run.
#
# La classificazione esistente/nuova/sparita è puro confronto MIUR (presenza del
# codicescuola nelle due partizioni), MAI stato dell'account. Il dettaglio riga
# si salva solo per le scuole "esistente" (le rettifiche azionabili).
#
# ATTENZIONE: stessa connessione per calcola e persisti (le TEMP sono per-connessione).
class Miur::ImportDiff
  CLASS_KEY = %w[codicescuola annocorso sezioneanno combinazione codiceisbn disciplina].freeze
  # Oltre questo numero di righe di dettaglio (import anomalo, non una rettifica)
  # si salvano solo i rollup: mai cap silenzioso, il salto viene loggato.
  MAX_DETTAGLIO = 200_000
  TMP_RIGHE  = "miur_diff_righe_tmp".freeze
  TMP_SCUOLE = "miur_diff_scuole_tmp".freeze

  def initialize(anno:, staging: "miur_adozioni_stg")
    @anno = anno.to_s
    @staging = staging
    @calcolato = false
  end

  attr_reader :anno, :staging

  # Primo import dell'anno: nessuna partizione vecchia => nessun diff possibile.
  def partizione
    @partizione ||= "miur_adozioni_#{anno}"
  end

  def partizione_esiste?
    conn.select_value("SELECT to_regclass('#{partizione}')").present?
  end

  def calcola
    return unless partizione_esiste?

    key = CLASS_KEY.join(", ")
    conn.execute("DROP TABLE IF EXISTS #{TMP_RIGHE}")
    conn.execute("DROP TABLE IF EXISTS #{TMP_SCUOLE}")

    # Dettaglio: EXCEPT sulla sola class-key (un cambio di titolo a parità di
    # ISBN non è una rettifica). titolo/tipogradoscuola arricchiti dopo, dal
    # lato giusto: '+' dalla staging, '-' dalla partizione vecchia (che con lo
    # swap sparisce: questa è l'unica copia superstite).
    conn.execute(<<~SQL)
      CREATE TEMP TABLE #{TMP_RIGHE} ON COMMIT PRESERVE ROWS AS
      WITH aggiunte AS (
        SELECT #{key} FROM #{staging} WHERE anno_scolastico = '#{anno}'
        EXCEPT
        SELECT #{key} FROM #{partizione}
      ),
      rimosse AS (
        SELECT #{key} FROM #{partizione}
        EXCEPT
        SELECT #{key} FROM #{staging} WHERE anno_scolastico = '#{anno}'
      )
      SELECT '+' AS segno, a.*,
             (SELECT s.titolo FROM #{staging} s
               WHERE s.codicescuola = a.codicescuola AND s.codiceisbn = a.codiceisbn
                 AND s.anno_scolastico = '#{anno}' LIMIT 1) AS titolo,
             (SELECT s.tipogradoscuola FROM #{staging} s
               WHERE s.codicescuola = a.codicescuola AND s.anno_scolastico = '#{anno}'
               LIMIT 1) AS tipogradoscuola
      FROM aggiunte a
      UNION ALL
      SELECT '-' AS segno, r.*,
             (SELECT p.titolo FROM #{partizione} p
               WHERE p.codicescuola = r.codicescuola AND p.codiceisbn = r.codiceisbn
               LIMIT 1) AS titolo,
             (SELECT p.tipogradoscuola FROM #{partizione} p
               WHERE p.codicescuola = r.codicescuola LIMIT 1) AS tipogradoscuola
      FROM rimosse r
    SQL

    # Rollup per scuola: categoria dal FULL OUTER JOIN dei codici presenti nelle
    # due partizioni; le "esistente" entrano solo se hanno righe nel diff.
    # provincia da miur_scuole dell'anno (NULL se il codice non è in anagrafe).
    conn.execute(<<~SQL)
      CREATE TEMP TABLE #{TMP_SCUOLE} ON COMMIT PRESERVE ROWS AS
      WITH vecchi AS (SELECT DISTINCT codicescuola FROM #{partizione}),
      nuovi AS (SELECT DISTINCT codicescuola FROM #{staging} WHERE anno_scolastico = '#{anno}'),
      classificate AS (
        SELECT COALESCE(v.codicescuola, n.codicescuola) AS codicescuola,
               CASE WHEN v.codicescuola IS NULL THEN 'nuova'
                    WHEN n.codicescuola IS NULL THEN 'sparita'
                    ELSE 'esistente' END AS categoria
        FROM vecchi v FULL OUTER JOIN nuovi n USING (codicescuola)
      ),
      conteggi AS (
        SELECT codicescuola,
               COUNT(*) FILTER (WHERE segno = '+') AS righe_aggiunte,
               COUNT(*) FILTER (WHERE segno = '-') AS righe_rimosse,
               MAX(tipogradoscuola) AS tipogradoscuola
        FROM #{TMP_RIGHE} GROUP BY codicescuola
      )
      SELECT c.codicescuola, c.categoria,
             ms.provincia,
             COALESCE(cnt.tipogradoscuola,
                      (SELECT MAX(x.tipogradoscuola) FROM #{staging} x
                        WHERE x.codicescuola = c.codicescuola
                          AND x.anno_scolastico = '#{anno}')) AS tipogradoscuola,
             COALESCE(cnt.righe_aggiunte, 0) AS righe_aggiunte,
             COALESCE(cnt.righe_rimosse, 0) AS righe_rimosse
      FROM classificate c
      LEFT JOIN conteggi cnt USING (codicescuola)
      LEFT JOIN miur_scuole ms
        ON ms.codice_scuola = c.codicescuola AND ms.anno_scolastico = '#{anno}'
      WHERE c.categoria <> 'esistente' OR cnt.codicescuola IS NOT NULL
    SQL

    @calcolato = true
  end

  def persisti(run)
    return unless @calcolato

    conn.execute(<<~SQL)
      INSERT INTO miur_import_diff_scuole
        (import_run_id, codicescuola, categoria, provincia, tipogradoscuola,
         righe_aggiunte, righe_rimosse, created_at)
      SELECT #{run.id}, codicescuola, categoria, provincia, tipogradoscuola,
             righe_aggiunte, righe_rimosse, now()
      FROM #{TMP_SCUOLE}
    SQL

    dettaglio = conn.select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM #{TMP_RIGHE} r
      JOIN #{TMP_SCUOLE} s ON s.codicescuola = r.codicescuola AND s.categoria = 'esistente'
    SQL
    if dettaglio > MAX_DETTAGLIO
      Rails.logger.warn("[Miur::ImportDiff] run #{run.id}: dettaglio saltato " \
                        "(#{dettaglio} righe > #{MAX_DETTAGLIO}); salvati solo i rollup")
    else
      conn.execute(<<~SQL)
        INSERT INTO miur_import_diff_righe
          (import_run_id, codicescuola, segno, codiceisbn, titolo, disciplina,
           annocorso, sezioneanno, combinazione, created_at)
        SELECT #{run.id}, r.codicescuola, r.segno, r.codiceisbn, r.titolo,
               r.disciplina, r.annocorso, r.sezioneanno, r.combinazione, now()
        FROM #{TMP_RIGHE} r
        JOIN #{TMP_SCUOLE} s ON s.codicescuola = r.codicescuola AND s.categoria = 'esistente'
      SQL
    end
  ensure
    conn.execute("DROP TABLE IF EXISTS #{TMP_RIGHE}")
    conn.execute("DROP TABLE IF EXISTS #{TMP_SCUOLE}")
  end

  private

  def conn = ActiveRecord::Base.connection
end
