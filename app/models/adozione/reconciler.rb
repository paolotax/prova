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
  # La subquery src normalizza i nomi colonna (lower/UPPER) una volta sola; da lì
  # in poi il SQL è identico per le due sorgenti. ON CONFLICT DO NOTHING preserva
  # le righe esistenti (note, numero_copie, mia, libro_id): il reconcile non
  # riscrive lo snapshot di righe già presenti.
  def upsert_adozioni
    s = source
    c = s.col
    sql = <<~SQL
      INSERT INTO adozioni
        (id, account_id, classe_id, codice_isbn, anno_scolastico, anno_corso, codicescuola,
         titolo, editore, autori, disciplina, prezzo_cents,
         nuova_adozione, da_acquistare, consigliato, created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, cl.id, src.codiceisbn, :anno, src.annocorso, src.codicescuola,
         src.titolo, src.editore, src.autori, src.disciplina,
         #{PREZZO_CENTS},
         #{s.si.call('src.nuovaadoz')},
         #{s.si.call('src.daacquist')},
         #{s.si.call('src.consigliato')},
         now(), now()
      FROM (
        SELECT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
               #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione,
               #{c[:codiceisbn]} AS codiceisbn, #{c[:daacquist]} AS daacquist,
               #{c[:titolo]} AS titolo, #{c[:editore]} AS editore,
               #{c[:autori]} AS autori, #{c[:disciplina]} AS disciplina,
               #{c[:prezzo]} AS prezzo, #{c[:nuovaadoz]} AS nuovaadoz,
               #{c[:consigliato]} AS consigliato
        FROM #{s.table}
      ) src
      JOIN scuole sc ON sc.codice_ministeriale = src.codicescuola
        AND sc.account_id = :account_id AND sc.provincia = :provincia
      JOIN classi cl ON cl.scuola_id = sc.id AND cl.anno_scolastico = :anno
        AND cl.anno_corso IS NOT DISTINCT FROM src.annocorso
        AND cl.sezione IS NOT DISTINCT FROM src.sezioneanno
        AND cl.combinazione IS NOT DISTINCT FROM src.combinazione
      WHERE src.codiceisbn IS NOT NULL
      ON CONFLICT (classe_id, codice_isbn, anno_scolastico) DO NOTHING
    SQL
    exec_sql(sql)
  end
  # DELETE raw: bypassa dependent: :destroy — per questo le orfane con dati
  # utente (consegne_saggio, numero_copie, note) NON si toccano. Il match
  # sorgente passa dalla classe (sezione/combinazione comprese), non dal solo
  # codicescuola+annocorso: un ISBN rimosso dalla 1B ma presente in 1A deve
  # sparire dalla 1B.
  def cancella_adozioni_orfane
    s = source
    c = s.col
    orfana = <<~SQL
      a.classe_id = cl.id AND cl.scuola_id = sc.id
        AND sc.account_id = :account_id AND sc.provincia = :provincia
        AND a.anno_scolastico = :anno
        AND NOT EXISTS (
          SELECT 1 FROM #{s.table} src_m
          WHERE src_m.#{c[:codicescuola]} = cl.codice_ministeriale_origine
            AND src_m.#{c[:annocorso]}    IS NOT DISTINCT FROM cl.anno_corso
            AND src_m.#{c[:sezioneanno]}  IS NOT DISTINCT FROM cl.sezione
            AND src_m.#{c[:combinazione]} IS NOT DISTINCT FROM cl.combinazione
            AND src_m.#{c[:codiceisbn]}   = a.codice_isbn
        )
    SQL
    protetta = <<~SQL
      (EXISTS (SELECT 1 FROM consegne_saggio cs WHERE cs.adozione_id = a.id)
        OR COALESCE(a.numero_copie, 0) <> 0
        OR a.note IS NOT NULL)
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
