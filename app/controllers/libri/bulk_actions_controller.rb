class Libri::BulkActionsController < ApplicationController

  before_action :authenticate_user!

  def carrello
    puts "=== CARRELLO CHIAMATO CON LIBRO_IDS: #{params[:libro_ids]} ==="
    @libri = Libro.where(id: params[:libro_ids])

    # Creare un nuovo documento ordine come bozza (senza validazioni richieste)
    @documento = current_user.documenti.build(
      data_documento: Date.today,
      status: 'bozza'
    )
    puts "=== DOCUMENTO CREATO: #{@documento.inspect} ==="
    

    if @documento.save
      # Aggiungere i libri come righe del documento
      @libri.each do |libro|
        # Creo prima la Riga
        riga = Riga.create!(
          libro_id: libro.id,
          prezzo_cents: libro.prezzo_in_cents,
          quantita: 1
        )
        # Poi creo la DocumentoRiga che collega documento e riga
        @documento.documento_righe.create!(riga: riga)
      end

      respond_to do |format|
        format.html { redirect_to @documento, notice: "Nuovo ordine creato con #{@libri.count} libri", status: :see_other }
        format.turbo_stream { redirect_to @documento, notice: "Nuovo ordine creato con #{@libri.count} libri", status: :see_other }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: libri_path, alert: "Errore nella creazione dell'ordine") }
        format.turbo_stream { redirect_back(fallback_location: libri_path, alert: "Errore nella creazione dell'ordine") }
      end
    end
  end

  def aggiungi
    @libri = Libro.where(id: params[:libro_ids])
    @documento_id = params[:documento_id]

    # Se non è specificato un documento_id, prendi l'ultimo documento dell'utente
    if @documento_id.present?
      @documento = current_user.documenti.find(@documento_id)
    else
      # Trova l'ultimo documento dell'utente (ordinato per data e numero documento)
      @documento = current_user.documenti.order(data_documento: :desc, numero_documento: :desc).first

      unless @documento
        respond_to do |format|
          format.html { redirect_back(fallback_location: libri_path, alert: "Nessun ordine disponibile. Crea prima un nuovo ordine.") }
          format.turbo_stream { redirect_back(fallback_location: libri_path, alert: "Nessun ordine disponibile. Crea prima un nuovo ordine.") }
        end
        return
      end
    end

    @libri.each do |libro|
      # Crea prima la Riga (come nel metodo carrello)
      riga = Riga.create!(
        libro_id: libro.id,
        prezzo_cents: libro.prezzo_in_cents,
        quantita: 1
      )

      # Poi crea la DocumentoRiga che collega documento e riga
      @documento.documento_righe.create!(riga: riga)
    end

    respond_to do |format|
      format.html { redirect_to @documento, notice: "#{@libri.count} libri aggiunti all'ordine ##{@documento.numero_documento}", status: :see_other }
      format.turbo_stream { redirect_to @documento, notice: "#{@libri.count} libri aggiunti all'ordine ##{@documento.numero_documento}", status: :see_other }
    end
  end

end