class BackfillDirezioniJob < ApplicationJob
  queue_as :bulk

  def perform(account)
    rows = account.scuole
      .joins(:import_scuola)
      .where(direzione_id: nil)
      .where(
        'import_scuole."CODICEISTITUTORIFERIMENTO" IS NOT NULL ' \
        'AND import_scuole."CODICEISTITUTORIFERIMENTO" <> import_scuole."CODICESCUOLA"'
      )
      .pluck(:id, 'import_scuole."CODICEISTITUTORIFERIMENTO"')

    return if rows.empty?

    codici_rif = rows.map(&:last).uniq

    presenti = account.scuole.where(codice_ministeriale: codici_rif).pluck(:codice_ministeriale).to_set
    mancanti = codici_rif - presenti.to_a

    if mancanti.any?
      gradi = TipoScuola.pluck(:tipo, :grado).to_h
      import_dirs = ImportScuola.where(CODICESCUOLA: mancanti).to_a
      records = import_dirs.map { |is| direzione_attributes(is, account, gradi) }
      Scuola.upsert_all(records, unique_by: %i[account_id codice_ministeriale]) if records.any?
    end

    sql = <<~SQL
      UPDATE scuole AS plesso
      SET direzione_id = sub.dir_id, updated_at = NOW()
      FROM (
        SELECT s.id AS plesso_id, dir.id AS dir_id
        FROM scuole s
        JOIN import_scuole is_plesso ON is_plesso.id = s.import_scuola_id
        JOIN scuole dir
          ON dir.account_id = s.account_id
         AND dir.codice_ministeriale = is_plesso."CODICEISTITUTORIFERIMENTO"
        WHERE s.account_id = :aid
          AND s.direzione_id IS NULL
          AND is_plesso."CODICEISTITUTORIFERIMENTO" IS NOT NULL
          AND is_plesso."CODICEISTITUTORIFERIMENTO" <> is_plesso."CODICESCUOLA"
      ) sub
      WHERE plesso.id = sub.plesso_id
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, aid: account.id])
    )
  end

  private

  def direzione_attributes(import_scuola, account, gradi)
    now = Time.current
    tipo = import_scuola.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA
    pec = import_scuola.INDIRIZZOPECSCUOLA
    pec = nil if pec.present? && pec.downcase.include?("non disponibil")

    {
      id: SecureRandom.uuid,
      account_id: account.id,
      import_scuola_id: import_scuola.id,
      direzione_id: nil,
      codice_ministeriale: import_scuola.CODICESCUOLA,
      denominazione: import_scuola.DENOMINAZIONESCUOLA,
      indirizzo: import_scuola.INDIRIZZOSCUOLA,
      cap: import_scuola.CAPSCUOLA,
      comune: import_scuola.DESCRIZIONECOMUNE,
      provincia: import_scuola.PROVINCIA&.upcase,
      regione: import_scuola.REGIONE&.upcase,
      tipo_scuola: tipo&.upcase,
      email: import_scuola.INDIRIZZOEMAILSCUOLA,
      pec: pec,
      grado: gradi[tipo],
      latitude: import_scuola.latitude,
      longitude: import_scuola.longitude,
      created_at: now,
      updated_at: now
    }
  end
end
