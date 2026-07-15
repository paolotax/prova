# Inserimento idempotente in anagrafe account (plessi + direzioni mancanti) a
# partire da righe miur_scuole. ON CONFLICT DO NOTHING: una scuola gia' in
# anagrafe non viene sovrascritta (protegge le modifiche utente).
class Scuola::AnagrafeMiur
  def initialize(account:, miur_scuole:, anno:)
    @account = account
    @miur_scuole = miur_scuole.to_a
    @anno = anno.to_s
  end

  def call
    return if miur_scuole.empty?

    inserisci_direzioni_mancanti
    dir_map = account.scuole.where(codice_ministeriale: codici_direzione)
                     .pluck(:codice_ministeriale, :id).to_h
    records = miur_scuole.map do |n|
      dir = n.codice_istituto_riferimento
      direzione_id = (dir.present? && dir != n.codice_scuola) ? dir_map[dir] : nil
      attributes(n, direzione_id)
    end
    Scuola.insert_all(records, unique_by: %i[account_id codice_ministeriale])
  end

  private

  attr_reader :account, :miur_scuole, :anno

  def codici_direzione
    @codici_direzione ||= miur_scuole.filter_map { |n|
      c = n.codice_istituto_riferimento
      c if c.present? && c != n.codice_scuola
    }.uniq
  end

  def inserisci_direzioni_mancanti
    mancanti = codici_direzione -
               account.scuole.where(codice_ministeriale: codici_direzione).pluck(:codice_ministeriale)
    return if mancanti.empty?

    records = Miur::Scuola.where(anno_scolastico: anno, codice_scuola: mancanti)
                          .map { |n| attributes(n, nil) }
    Scuola.insert_all(records, unique_by: %i[account_id codice_ministeriale]) if records.any?
  end

  def gradi
    @gradi ||= TipoScuola.pluck(:tipo, :grado).to_h
  end

  def sigle
    @sigle ||= account.scuole.where.not(sigla_provincia: [nil, ""])
                      .distinct.pluck(:provincia, :sigla_provincia).to_h
  end

  def attributes(new_scuola, direzione_id)
    now = Time.current
    pec = new_scuola.pec
    pec = nil if pec.present? && pec.downcase.include?("non disponibil")
    provincia = new_scuola.provincia&.upcase

    {
      id: SecureRandom.uuid,
      account_id: account.id,
      import_scuola_id: new_scuola.import_scuola_id,
      direzione_id: direzione_id,
      codice_ministeriale: new_scuola.codice_scuola,
      denominazione: new_scuola.denominazione,
      indirizzo: new_scuola.indirizzo,
      cap: new_scuola.cap,
      comune: new_scuola.comune,
      provincia: provincia,
      sigla_provincia: sigle[provincia],
      regione: new_scuola.regione&.upcase,
      tipo_scuola: new_scuola.tipo_scuola,
      email: new_scuola.email,
      pec: pec,
      grado: gradi[new_scuola.tipo_scuola],
      created_at: now,
      updated_at: now
    }
  end
end
