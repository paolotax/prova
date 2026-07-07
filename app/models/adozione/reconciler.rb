class Adozione::Reconciler
  # Ricostruzione set-based idempotente di classi/adozioni storicizzate per
  # (account, provincia, anno). Sostituisce il fan-out per-scuola della promozione.
  # Stesso pattern di ControlloAdozioni::Rebuild: transazione + advisory lock.
  #
  # ATTENZIONE: ogni nuova subquery su miur_adozioni DEVE filtrare
  # anno_scolastico = :anno (tabella unica partizionata, non più una per anno).

  # Prezzo stringa "12,34" -> cents int (0 se non numerico). Idioma da
  # ControlloAdozioni::Rebuild::PREZZO_CENTS: classi POSIX, round su numeric.
  PREZZO_CENTS = "CASE WHEN replace(src.prezzo, ',', '.') ~ '^[0-9]+([.][0-9]+)?$' " \
                 "THEN round(replace(src.prezzo, ',', '.')::numeric * 100)::int " \
                 "ELSE 0 END".freeze

  def initialize(account:, provincia:, anno:)
    @account = account
    @provincia = provincia
    @anno = anno.to_s
  end

  # Sorgente unica: la tabella partizionata miur_adozioni. Ogni subquery che la
  # legge DEVE filtrare anno_scolastico = :anno — con una tabella sola il filtro
  # anno non è più implicito nella scelta della tabella.
  #
  # Stato derivato dall'anno: l'anno corrente (max pubblicato in anagrafe MIUR)
  # nasce attivo; gli anni passati nascono archiviati (storico). Le fasi
  # riattiva/archivia girano solo per l'anno corrente.
  def stato
    @stato ||= (anno == Miur.anno_corrente ? "attiva" : "archiviata")
  end

  def call
    # Fail-fast: con miur_scuole vuota Miur.anno_corrente è nil, lo stato
    # collasserebbe ad "archiviata" anche per l'anno corrente etichettando in
    # silenzio l'intera provincia. Meglio un crash retry-safe.
    raise Miur::ImportError, "anno_corrente nil (miur_scuole vuota): reconcile abortito" if Miur.anno_corrente.nil?

    ApplicationRecord.transaction do
      exec_sql("SELECT pg_advisory_xact_lock(hashtext(:lock_key))",
               lock_key: "reconcile/#{account.id}/#{provincia}/#{anno}")
      archivia_anni_precedenti
      riattiva_classi
      upsert_classi
      archivia_classi_orfane
      upsert_adozioni
      cancella_adozioni_orfane
    end
    ricalcola
  end

  private

  attr_reader :account, :provincia, :anno

  def params
    { account_id: account.id, provincia: provincia, anno: anno }
  end

  def exec_sql(sql, extra = {})
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, params.merge(extra)])
    )
  end

  # "vale sì" robusto a "Si"/"S"/"SI" e a null (COALESCE). Unico per la sorgente
  # miur_adozioni: le vecchie grafie (new = ILIKE 'S%', import = "= 'Si'")
  # sono entrambe coperte.
  def si(expr) = "COALESCE(#{expr}, '') ILIKE 'S%'"

  # L'indice unico parziale sulle attive NON include anno_scolastico: "attiva"
  # esiste una sola volta per (scuola, anno_corso, sezione, combinazione)
  # attraverso gli anni. Le attive di anni precedenti vanno archiviate PRIMA di
  # costruire il corrente — ma SOLO per le scuole presenti nella sorgente, come
  # faceva la promozione per-scuola (promuovibile ⇒ nel MIUR). Le scuole in
  # attesa del rilascio cumulativo MIUR tengono le classi vecchie attive:
  # azzerarle le farebbe sparire dalla panoramica (con_adozioni? richiede
  # adozioni_count > 0 o presenza in miur_adozioni). Solo UPDATE di stato:
  # reversibile, nessuna cancellazione.
  def archivia_anni_precedenti
    return unless stato == "attiva"

    exec_sql(<<~SQL)
      UPDATE classi cl SET stato = 'archiviata', updated_at = now()
      FROM scuole sc
      WHERE cl.scuola_id = sc.id
        AND sc.account_id = :account_id AND sc.provincia = :provincia
        AND cl.stato = 'attiva'
        AND cl.anno_scolastico IS DISTINCT FROM :anno
        AND EXISTS (
          SELECT 1 FROM miur_adozioni src_p
          WHERE src_p.codicescuola = sc.codice_ministeriale
            AND src_p.anno_scolastico = :anno
        )
    SQL
  end

  # Le fasi riattiva/archivia girano solo per l'anno corrente: lo storico
  # (anni passati) nasce e resta archiviato. Il rilascio MIUR è cumulativo:
  # una classe archiviata come orfana può ricomparire in sorgente → si riattiva
  # PRIMA dell'upsert, così il NOT EXISTS la trova e non duplica.
  def riattiva_classi
    return unless stato == "attiva"

    exec_sql(<<~SQL)
      UPDATE classi cl SET stato = 'attiva', updated_at = now()
      FROM scuole sc
      WHERE cl.scuola_id = sc.id
        AND sc.account_id = :account_id AND sc.provincia = :provincia
        AND cl.anno_scolastico = :anno
        AND cl.stato = 'archiviata'
        AND EXISTS (#{sorgente_match_classe})
    SQL
  end

  def archivia_classi_orfane
    return unless stato == "attiva"

    exec_sql(<<~SQL)
      UPDATE classi cl SET stato = 'archiviata', updated_at = now()
      FROM scuole sc
      WHERE cl.scuola_id = sc.id
        AND sc.account_id = :account_id AND sc.provincia = :provincia
        AND cl.anno_scolastico = :anno
        AND cl.stato = 'attiva'
        AND NOT EXISTS (#{sorgente_match_classe})
    SQL
  end

  # Subquery riusata da riattiva/archivia: la classe cl esiste in sorgente?
  def sorgente_match_classe
    <<~SQL
      SELECT 1 FROM miur_adozioni src_m
      WHERE src_m.codicescuola = cl.codice_ministeriale_origine
        AND src_m.anno_scolastico = :anno
        AND src_m.annocorso    IS NOT DISTINCT FROM cl.anno_corso
        AND src_m.sezioneanno  IS NOT DISTINCT FROM cl.sezione
        AND src_m.combinazione IS NOT DISTINCT FROM cl.combinazione
    SQL
  end

  def upsert_classi
    sql = <<~SQL
      INSERT INTO classi
        (id, account_id, scuola_id, anno_corso, sezione, combinazione,
         anno_scolastico, stato, tipo_scuola,
         codice_ministeriale_origine, classe_origine, sezione_origine, combinazione_origine,
         created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, sc.id,
             src.annocorso, src.sezioneanno, src.combinazione,
             :anno, '#{stato}', sc.tipo_scuola,
             src.codicescuola, src.annocorso, src.sezioneanno, src.combinazione,
             now(), now()
      FROM (
        SELECT DISTINCT codicescuola, annocorso, sezioneanno, combinazione
        FROM miur_adozioni
        WHERE anno_scolastico = :anno
      ) src
      JOIN scuole sc ON sc.codice_ministeriale = src.codicescuola
        AND sc.account_id = :account_id AND sc.provincia = :provincia
      WHERE NOT EXISTS (
        SELECT 1 FROM classi cl
        WHERE cl.scuola_id = sc.id
          AND cl.anno_scolastico = :anno
          AND cl.anno_corso IS NOT DISTINCT FROM src.annocorso
          AND cl.sezione IS NOT DISTINCT FROM src.sezioneanno
          AND cl.combinazione IS NOT DISTINCT FROM src.combinazione
      )
    SQL
    exec_sql(sql)
  end
  # ON CONFLICT DO NOTHING preserva le righe esistenti (note, numero_copie, mia,
  # libro_id): il reconcile non riscrive lo snapshot di righe già presenti.
  def upsert_adozioni
    sql = <<~SQL
      INSERT INTO adozioni
        (id, account_id, classe_id, codice_isbn, anno_scolastico, anno_corso, codicescuola,
         titolo, editore, autori, disciplina, prezzo_cents,
         nuova_adozione, da_acquistare, consigliato, created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, cl.id, src.codiceisbn, :anno, src.annocorso, src.codicescuola,
         src.titolo, src.editore, src.autori, src.disciplina,
         #{PREZZO_CENTS},
         #{si('src.nuovaadoz')},
         #{si('src.daacquist')},
         #{si('src.consigliato')},
         now(), now()
      FROM miur_adozioni src
      JOIN scuole sc ON sc.codice_ministeriale = src.codicescuola
        AND sc.account_id = :account_id AND sc.provincia = :provincia
      JOIN classi cl ON cl.scuola_id = sc.id AND cl.anno_scolastico = :anno
        AND cl.anno_corso IS NOT DISTINCT FROM src.annocorso
        AND cl.sezione IS NOT DISTINCT FROM src.sezioneanno
        AND cl.combinazione IS NOT DISTINCT FROM src.combinazione
      WHERE src.anno_scolastico = :anno
        AND src.codiceisbn IS NOT NULL
      ON CONFLICT (classe_id, codice_isbn, anno_scolastico) DO NOTHING
    SQL
    exec_sql(sql)
  end
  # DELETE raw: bypassa dependent: :destroy — per questo le orfane con dati
  # utente (consegne_saggio, numero_copie, note) o dell'editore (mia) NON si
  # toccano. mia è derivato dai mandati (Ricalcolo): se il mandato regge, la
  # riga resta protetta a ogni run; un mia spurio decade col ricalcolo e la
  # riga cade al run successivo. Il match sorgente passa dalla classe
  # (sezione/combinazione comprese), non dal solo codicescuola+annocorso: un
  # ISBN rimosso dalla 1B ma presente in 1A deve sparire dalla 1B.
  def cancella_adozioni_orfane
    orfana = <<~SQL
      a.classe_id = cl.id AND cl.scuola_id = sc.id
        AND sc.account_id = :account_id AND sc.provincia = :provincia
        AND a.anno_scolastico = :anno
        AND NOT EXISTS (
          SELECT 1 FROM miur_adozioni src_m
          WHERE src_m.codicescuola = cl.codice_ministeriale_origine
            AND src_m.anno_scolastico = :anno
            AND src_m.annocorso    IS NOT DISTINCT FROM cl.anno_corso
            AND src_m.sezioneanno  IS NOT DISTINCT FROM cl.sezione
            AND src_m.combinazione IS NOT DISTINCT FROM cl.combinazione
            AND src_m.codiceisbn   = a.codice_isbn
        )
    SQL
    protetta = <<~SQL
      (EXISTS (SELECT 1 FROM consegne_saggio cs WHERE cs.adozione_id = a.id)
        OR COALESCE(a.numero_copie, 0) <> 0
        OR a.note IS NOT NULL
        OR a.mia)
    SQL

    protette = exec_sql(<<~SQL).first["cnt"]
      SELECT COUNT(*) AS cnt FROM adozioni a, classi cl, scuole sc
      WHERE #{orfana} AND #{protetta}
    SQL
    if protette.positive?
      Rails.logger.info("[Adozione::Reconciler] #{account.id} #{provincia} #{anno}: " \
                        "#{protette} adozioni orfane protette (dati utente), non cancellate")
    end

    exec_sql(<<~SQL)
      DELETE FROM adozioni a
      USING classi cl, scuole sc
      WHERE #{orfana} AND NOT #{protetta}
    SQL
  end
  # Fuori dalla transazione del reconcile: tocca scuole/adozioni con lock propri.
  def ricalcola
    scuola_ids = account.scuole.where(provincia: provincia).pluck(:id)
    Adozione::Ricalcolo.new(account: account, scuola_ids: scuola_ids).call
  end
end
