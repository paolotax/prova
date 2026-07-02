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

  def riattiva_classi          = nil
  def upsert_classi            = nil
  def archivia_classi_orfane   = nil
  def upsert_adozioni          = nil
  def cancella_adozioni_orfane = nil
  def ricalcola                = nil
end
