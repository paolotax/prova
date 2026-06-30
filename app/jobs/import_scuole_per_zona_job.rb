class ImportScuolePerZonaJob < ApplicationJob
  queue_as :bulk
  discard_on ActiveJob::DeserializationError

  # Anno scolastico del dataset import_adozioni (set ministeriale stabile dell'anno scorso).
  # ImportAdozione.anno_scolastico e' attualmente nil, quindi lo stampiamo qui esplicitamente.
  # BUMPARE quando il dataset import_adozioni passa all'anno scolastico successivo.
  ANNO_SCOLASTICO = "202526"

  include ActionView::RecordIdentifier
  include BroadcastsPulsanteAggiornaAdozioni

  def perform(account_zona)
    account = account_zona.account
    account_zona.update!(stato: "importazione")

    codici = import_codici(account_zona)

    import_scuole_batch(account, account_zona, codici)
    import_classi_batch(account, codici)
    import_adozioni_batch(account, codici)

    account_zona.update!(scuole_count: codici.size, stato: "attiva")
    account.estendi_mandati_a_zona!(provincia: account_zona.provincia, grado: account_zona.grado)
    broadcast_zone_panel(account)
    broadcast_scuole_refresh(account)
    broadcast_pulsante_stato(account)
  end

  private

  def import_codici(account_zona)
    account_zona.import_scuole_per_zona.pluck(:CODICESCUOLA)
  end

  # Fase 1: upsert scuole
  def import_scuole_batch(account, account_zona, codici)
    gradi = TipoScuola.pluck(:tipo, :grado).to_h
    import_scuole = ImportScuola.where(CODICESCUOLA: codici).to_a

    # Trova codici direzioni (CODICEISTITUTORIFERIMENTO diverso da CODICESCUOLA)
    dir_codici = import_scuole
      .select { |is| is.CODICEISTITUTORIFERIMENTO.present? && is.CODICEISTITUTORIFERIMENTO != is.CODICESCUOLA }
      .map(&:CODICEISTITUTORIFERIMENTO).uniq

    # Upsert direzioni prima dei plessi
    if dir_codici.any?
      dir_imports = ImportScuola.where(CODICESCUOLA: dir_codici).to_a
      dir_records = dir_imports.map { |is| scuola_attributes(is, account, gradi, nil) }
      Scuola.upsert_all(dir_records, unique_by: %i[account_id codice_ministeriale]) if dir_records.any?
    end

    # Mappa codice_ministeriale → id per le direzioni
    dir_map = account.scuole.where(codice_ministeriale: dir_codici).pluck(:codice_ministeriale, :id).to_h

    # Upsert tutte le scuole della zona
    records = import_scuole.map do |is|
      dir_codice = is.CODICEISTITUTORIFERIMENTO
      direzione_id = (dir_codice.present? && dir_codice != is.CODICESCUOLA) ? dir_map[dir_codice] : nil
      scuola_attributes(is, account, gradi, direzione_id)
    end
    Scuola.upsert_all(records, unique_by: %i[account_id codice_ministeriale]) if records.any?
  end

  def scuola_attributes(import_scuola, account, gradi, direzione_id)
    now = Time.current
    tipo = import_scuola.DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA
    pec = import_scuola.INDIRIZZOPECSCUOLA
    pec = nil if pec.present? && pec.downcase.include?("non disponibil")

    {
      id: SecureRandom.uuid,
      account_id: account.id,
      import_scuola_id: import_scuola.id,
      direzione_id: direzione_id,
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

  # Fase 2: insert classi (derivate da ImportAdozione, senza Views::Classe)
  def import_classi_batch(account, codici)
    scuola_map = account.scuole.where(codice_ministeriale: codici).pluck(:codice_ministeriale, :id).to_h

    # Tipo scuola per ogni codice ministeriale (dalla scuola già importata)
    tipo_map = account.scuole.where(codice_ministeriale: codici).pluck(:codice_ministeriale, :tipo_scuola).to_h

    # Classi distinte direttamente da import_adozioni
    distinct_classi = ImportAdozione.where(CODICESCUOLA: codici)
      .distinct
      .pluck(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE)

    now = Time.current
    records = distinct_classi.filter_map do |codice, anno, sezione, combinazione|
      scuola_id = scuola_map[codice]
      next unless scuola_id

      {
        id: SecureRandom.uuid,
        account_id: account.id,
        scuola_id: scuola_id,
        anno_corso: anno,
        sezione: sezione,
        combinazione: combinazione,
        anno_scolastico: ANNO_SCOLASTICO,
        stato: "attiva",
        tipo_scuola: tipo_map[codice],
        codice_ministeriale_origine: codice,
        classe_origine: anno,
        sezione_origine: sezione,
        combinazione_origine: combinazione,
        created_at: now,
        updated_at: now
      }
    end

    Classe.insert_all(records, unique_by: :index_classi_attive_on_scuola_anno_sezione_combinazione) if records.any?
  end

  # Fase 3: insert adozioni
  def import_adozioni_batch(account, codici)
    classe_map = account.classi
      .where(codice_ministeriale_origine: codici)
      .pluck(:codice_ministeriale_origine, :classe_origine, :sezione_origine, :combinazione_origine, :id)
      .each_with_object({}) { |(cm, cl, sez, comb, id), h| h[[cm, cl, sez, comb]] = id }

    libro_map = account.libri.pluck(:codice_isbn, :id).to_h

    import_adozioni = ImportAdozione.where(CODICESCUOLA: codici).to_a
    now = Time.current

    records = import_adozioni.filter_map do |ia|
      classe_id = classe_map[[ia.CODICESCUOLA, ia.ANNOCORSO, ia.SEZIONEANNO, ia.COMBINAZIONE]]
      next unless classe_id

      {
        id: SecureRandom.uuid,
        account_id: account.id,
        classe_id: classe_id,
        import_adozione_id: ia.id,
        libro_id: libro_map[ia.CODICEISBN],
        codice_isbn: ia.CODICEISBN,
        anno_scolastico: ANNO_SCOLASTICO,
        anno_corso: ia.ANNOCORSO,
        codicescuola: ia.CODICESCUOLA,
        titolo: ia.TITOLO,
        editore: ia.EDITORE,
        autori: ia.AUTORI,
        disciplina: ia.DISCIPLINA,
        prezzo_cents: (ia.PREZZO.to_s.gsub(",", ".").to_f * 100).to_i,
        nuova_adozione: ia.NUOVAADOZ == "Si",
        da_acquistare: ia.DAACQUIST == "Si",
        consigliato: ia.CONSIGLIATO == "Si",
        created_at: now,
        updated_at: now
      }
    end

    records.each_slice(5000) do |batch|
      Adozione.insert_all(batch, unique_by: :index_adozioni_on_classe_isbn_anno)
    end
  end

  def broadcast_zone_panel(account)
    account_zone = account.zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "accounts/zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end

  def broadcast_scuole_refresh(account)
    account.memberships.find_each do |membership|
      Turbo::StreamsChannel.broadcast_refresh_later_to(membership, "scuole")
    end
  end
end
