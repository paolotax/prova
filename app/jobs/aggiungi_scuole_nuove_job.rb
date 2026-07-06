class AggiungiScuoleNuoveJob < ApplicationJob
  queue_as :bulk

  # Aggiunge in blocco all'anagrafe account le "nuove scuole" del controllo adozioni
  # (codici in miur_scuole+miur_adozioni senza predecessore ne' candidati), opzionalmente
  # di una sola provincia. Anagrafe da miur_scuole (direzioni comprese), poi classi e
  # adozioni via Adozione::Reconciler per provincia (idempotente, ricalcola i contatori).
  def perform(account, provincia: nil)
    Current.account = account
    anno = Miur.anno_corrente
    return if anno.blank?

    scuole = provincia ? account.scuole.where(provincia: provincia) : nil
    panoramica = ControlloAdozioni::Panoramica.new(account: account, scuole: scuole,
                                                   provincia: provincia)
    nuove = panoramica.cambi_codice.select { |m| m.tipo == :nuova }
    return if nuove.empty?

    province = inserisci_scuole(account, nuove.map(&:codice), anno)
    province.each { |prov| Adozione::Reconciler.new(account: account, provincia: prov, anno: anno).call }

    broadcast(account, province)
  end

  private

  # Insert idempotente (ON CONFLICT DO NOTHING) delle scuole e delle loro eventuali
  # direzioni non ancora in account. Ritorna le province coinvolte.
  def inserisci_scuole(account, codici, anno)
    gradi = TipoScuola.pluck(:tipo, :grado).to_h
    sigle = account.scuole.where.not(sigla_provincia: [nil, ""])
                   .distinct.pluck(:provincia, :sigla_provincia).to_h
    nuove = Miur::Scuola.where(anno_scolastico: anno, codice_scuola: codici).to_a

    dir_codici = nuove.filter_map { |n|
      c = n.codice_istituto_riferimento
      c if c.present? && c != n.codice_scuola
    }.uniq
    dir_mancanti = dir_codici - account.scuole.where(codice_ministeriale: dir_codici).pluck(:codice_ministeriale)
    direzioni = Miur::Scuola.where(anno_scolastico: anno, codice_scuola: dir_mancanti).to_a
    if direzioni.any?
      Scuola.insert_all(direzioni.map { |n| scuola_attributes(n, account, gradi, sigle, nil) },
                        unique_by: %i[account_id codice_ministeriale])
    end

    dir_map = account.scuole.where(codice_ministeriale: dir_codici).pluck(:codice_ministeriale, :id).to_h
    records = nuove.map do |n|
      dir = n.codice_istituto_riferimento
      direzione_id = (dir.present? && dir != n.codice_scuola) ? dir_map[dir] : nil
      scuola_attributes(n, account, gradi, sigle, direzione_id)
    end
    Scuola.insert_all(records, unique_by: %i[account_id codice_ministeriale]) if records.any?

    nuove.map { |n| n.provincia&.upcase }.compact.uniq
  end

  def scuola_attributes(new_scuola, account, gradi, sigle, direzione_id)
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

  # Refresh completo (morph) delle viste interessate: dashboard admin, panoramica
  # delle province coinvolte e vista "tutte", elenco scuole.
  def broadcast(account, province)
    Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_dashboard")
    (province + ["_all"]).each do |scope|
      Turbo::StreamsChannel.broadcast_refresh_to(account, "controllo_adozioni_riepilogo", scope)
    end
    Turbo::StreamsChannel.broadcast_refresh_to(account, "scuole")
  end
end
