class Adozione::Reconciler
  # Ricostruzione set-based idempotente di classi/adozioni storicizzate per
  # (account, provincia, anno). Sostituisce il fan-out per-scuola della promozione.
  # Stesso pattern di ControlloAdozioni::Rebuild: transazione + advisory lock.

  # col: nome_logico → identificatore SQL (già quotato per import_adozioni).
  # si: espressione booleana "vale sì" per la colonna passata.
  Source = Struct.new(:table, :col, :stato, :si, keyword_init: true)

  # Prezzo stringa "12,34" -> cents int (0 se non numerico). Idioma da
  # ControlloAdozioni::Rebuild::PREZZO_CENTS: classi POSIX, round su numeric.
  PREZZO_CENTS = "CASE WHEN replace(src.prezzo, ',', '.') ~ '^[0-9]+([.][0-9]+)?$' " \
                 "THEN round(replace(src.prezzo, ',', '.')::numeric * 100)::int " \
                 "ELSE 0 END".freeze

  NEW = Source.new(
    table: "new_adozioni", stato: "attiva",
    si: ->(expr) { "COALESCE(#{expr}, '') ILIKE 'S%'" },
    col: { codicescuola: "codicescuola", annocorso: "annocorso",
           sezioneanno: "sezioneanno", combinazione: "combinazione",
           codiceisbn: "codiceisbn", daacquist: "daacquist", titolo: "titolo",
           editore: "editore", autori: "autori", disciplina: "disciplina",
           prezzo: "prezzo", nuovaadoz: "nuovaadoz", consigliato: "consigliato" }
  ).freeze

  IMPORT = Source.new(
    table: "import_adozioni", stato: "archiviata",
    si: ->(expr) { "#{expr} = 'Si'" },
    col: { codicescuola: %q{"CODICESCUOLA"}, annocorso: %q{"ANNOCORSO"},
           sezioneanno: %q{"SEZIONEANNO"}, combinazione: %q{"COMBINAZIONE"},
           codiceisbn: %q{"CODICEISBN"}, daacquist: %q{"DAACQUIST"},
           titolo: %q{"TITOLO"}, editore: %q{"EDITORE"}, autori: %q{"AUTORI"},
           disciplina: %q{"DISCIPLINA"}, prezzo: %q{"PREZZO"},
           nuovaadoz: %q{"NUOVAADOZ"}, consigliato: %q{"CONSIGLIATO"} }
  ).freeze

  def initialize(account:, provincia:, anno:)
    @account = account
    @provincia = provincia
    @anno = anno.to_s
  end

  def source
    @anno == "202627" ? NEW : IMPORT
  end

  def call
    ApplicationRecord.transaction do
      exec_sql("SELECT pg_advisory_xact_lock(hashtext(:lock_key))",
               lock_key: "reconcile/#{account.id}/#{provincia}/#{anno}")
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

  # Le fasi riattiva/archivia girano solo per l'anno corrente: lo storico
  # (import_adozioni) nasce e resta archiviato. Il rilascio MIUR è cumulativo:
  # una classe archiviata come orfana può ricomparire in sorgente → si riattiva
  # PRIMA dell'upsert, così il NOT EXISTS la trova e non duplica.
  def riattiva_classi
    return unless source.stato == "attiva"

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
    return unless source.stato == "attiva"

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
    c = source.col
    <<~SQL
      SELECT 1 FROM #{source.table} src_m
      WHERE src_m.#{c[:codicescuola]} = cl.codice_ministeriale_origine
        AND src_m.#{c[:annocorso]}    IS NOT DISTINCT FROM cl.anno_corso
        AND src_m.#{c[:sezioneanno]}  IS NOT DISTINCT FROM cl.sezione
        AND src_m.#{c[:combinazione]} IS NOT DISTINCT FROM cl.combinazione
    SQL
  end

  def upsert_classi
    s = source
    c = s.col
    sql = <<~SQL
      INSERT INTO classi
        (id, account_id, scuola_id, anno_corso, sezione, combinazione,
         anno_scolastico, stato, tipo_scuola,
         codice_ministeriale_origine, classe_origine, sezione_origine, combinazione_origine,
         created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, sc.id,
             src.annocorso, src.sezioneanno, src.combinazione,
             :anno, '#{s.stato}', sc.tipo_scuola,
             src.codicescuola, src.annocorso, src.sezioneanno, src.combinazione,
             now(), now()
      FROM (
        SELECT DISTINCT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
               #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione
        FROM #{s.table}
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
  def upsert_adozioni          = nil
  def cancella_adozioni_orfane = nil
  def ricalcola                = nil
end
