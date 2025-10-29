class CampionarioController < ApplicationController

  before_action :authenticate_user!

  def show
    @campionario = Current.user.documenti.includes(righe: :libro).find(params[:id])

    # Trova la causale "Campionario Resa"
    causale_resa = Causale.find_by(causale: "Campionario Resa")

    # Cerca la resa con stesso numero documento e data documento
    @resa = Current.user.documenti.includes(righe: :libro).where(
      causale_id: causale_resa&.id,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_id: @campionario.clientable_id,
      clientable_type: @campionario.clientable_type
    ).first

    # Trova la causale "saggi"
    causale_saggi = Causale.find_by(causale: "saggi")

    # Cerca il documento saggi con stesso numero documento e data documento
    @saggi = Current.user.documenti.includes(righe: :libro).where(
      causale_id: causale_saggi&.id,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_id: @campionario.clientable_id,
      clientable_type: @campionario.clientable_type
    ).first

    # Trova la causale "saggi 50"
    causale_saggi_50 = Causale.find_by(causale: "saggi 50")

    # Cerca il documento saggi 50 con stesso numero documento e data documento
    @saggi_50 = Current.user.documenti.includes(righe: :libro).where(
      causale_id: causale_saggi_50&.id,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_id: @campionario.clientable_id,
      clientable_type: @campionario.clientable_type
    ).first

    # Prepara i dati per il confronto
    # Creo una struttura con tutti i libri presenti in campionario, resa, saggi e saggi_50
    # Uso group_by invece di index_by per gestire righe duplicate per lo stesso libro_id
    campionario_righe = @campionario.righe.to_a.group_by(&:libro_id)
    resa_righe = @resa&.righe&.to_a&.group_by(&:libro_id) || {}
    saggi_righe = @saggi&.righe&.to_a&.group_by(&:libro_id) || {}
    saggi_50_righe = @saggi_50&.righe&.to_a&.group_by(&:libro_id) || {}

    # Unisco tutti i libro_id
    libro_ids = (campionario_righe.keys + resa_righe.keys + saggi_righe.keys + saggi_50_righe.keys).uniq.compact

    @confronto = libro_ids.map do |libro_id|
      # Per ogni libro, prendo tutte le righe e sommo le quantità
      righe_camp = campionario_righe[libro_id] || []
      righe_resa_arr = resa_righe[libro_id] || []
      righe_saggi_arr = saggi_righe[libro_id] || []
      righe_saggi_50_arr = saggi_50_righe[libro_id] || []

      {
        libro: righe_camp.first&.libro || righe_resa_arr.first&.libro || righe_saggi_arr.first&.libro || righe_saggi_50_arr.first&.libro,
        quantita_campionario: righe_camp.sum(&:quantita),
        quantita_resa: righe_resa_arr.sum(&:quantita),
        quantita_saggi: righe_saggi_arr.sum(&:quantita),
        quantita_saggi_50: righe_saggi_50_arr.sum(&:quantita),
        # Manteniamo le righe per i link (usiamo la prima riga disponibile)
        riga_campionario: righe_camp.first,
        riga_resa: righe_resa_arr.first,
        riga_saggi: righe_saggi_arr.first,
        riga_saggi_50: righe_saggi_50_arr.first
      }
    end.compact.sort_by { |row| row[:libro]&.titolo || "" }
  end

  def genera_saggi
    @campionario = Current.user.documenti.find(params[:id])

    # Trova la causale "saggi"
    causale_saggi = Causale.find_by(causale: "saggi")

    unless causale_saggi
      redirect_to campionario_path(@campionario), alert: "Causale 'saggi' non trovata"
      return
    end

    # Crea il documento saggi con stesso numero e data del campionario
    documento_saggi = Current.user.documenti.create!(
      causale: causale_saggi,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_type: @campionario.clientable_type,
      clientable_id: @campionario.clientable_id,
      referente: "Da campionario #{@campionario.numero_documento}",
      note: "Generato automaticamente da campionario #{@campionario.numero_documento}"
    )

    # Conta i fascicoli aggiunti
    fascicoli_aggiunti = 0
    posizione = 1

    # Trova tutti i libri dell'utente con adozioni_count > 0 e che hanno fascicoli
    libri_con_adozioni = Current.user.libri
      .includes(:fascicoli)
      .where("adozioni_count > ?", 0)
      .where.not(fascicoli_count: 0)

    # Per ogni libro con adozioni
    libri_con_adozioni.each do |libro|
      # Aggiungi ogni fascicolo al documento saggi
      libro.fascicoli.each do |fascicolo|
        documento_saggi.documento_righe.build(posizione: posizione).build_riga(
          libro_id: fascicolo.id,
          quantita: libro.adozioni_count,
          sconto: 100,
          prezzo_cents: fascicolo.prezzo_in_cents || 0,
          iva_cents: 0
        )
        posizione += 1
        fascicoli_aggiunti += 1
      end
    end

    if documento_saggi.save
      redirect_to documento_path(documento_saggi),
                  notice: "Documento saggi creato con successo! Aggiunti #{fascicoli_aggiunti} fascicoli."
    else
      redirect_to campionario_path(@campionario),
                  alert: "Errore nella creazione del documento saggi: #{documento_saggi.errors.full_messages.join(', ')}"
    end
  end

  def genera_saggi_50
    @campionario = Current.user.documenti.find(params[:id])

    # Trova la causale "saggi 50"
    causale_saggi_50 = Causale.find_by(causale: "saggi 50")

    unless causale_saggi_50
      redirect_to campionario_path(@campionario), alert: "Causale 'saggi 50' non trovata"
      return
    end

    # Crea il documento saggi 50 con stesso numero e data del campionario
    documento_saggi_50 = Current.user.documenti.create!(
      causale: causale_saggi_50,
      numero_documento: @campionario.numero_documento,
      data_documento: @campionario.data_documento,
      clientable_type: @campionario.clientable_type,
      clientable_id: @campionario.clientable_id,
      referente: "Da campionario #{@campionario.numero_documento}",
      note: "Generato automaticamente da campionario #{@campionario.numero_documento}"
    )

    # Conta i fascicoli aggiunti
    fascicoli_aggiunti = 0
    posizione = 1

    # Trova tutti i libri dell'utente con adozioni_count > 0 e che hanno fascicoli
    libri_con_adozioni = Current.user.libri
      .includes(:fascicoli)
      .where("adozioni_count > ?", 0)
      .where.not(fascicoli_count: 0)

    # Per ogni libro con adozioni
    libri_con_adozioni.each do |libro|
      # Aggiungi ogni fascicolo al documento saggi 50
      libro.fascicoli.each do |fascicolo|
        documento_saggi_50.documento_righe.build(posizione: posizione).build_riga(
          libro_id: fascicolo.id,
          quantita: libro.adozioni_count,
          sconto: 50,
          prezzo_cents: fascicolo.prezzo_in_cents || 0,
          iva_cents: 0
        )
        posizione += 1
        fascicoli_aggiunti += 1
      end
    end

    if documento_saggi_50.save
      redirect_to documento_path(documento_saggi_50),
                  notice: "Documento saggi 50 creato con successo! Aggiunti #{fascicoli_aggiunti} fascicoli."
    else
      redirect_to campionario_path(@campionario),
                  alert: "Errore nella creazione del documento saggi 50: #{documento_saggi_50.errors.full_messages.join(', ')}"
    end
  end

end
