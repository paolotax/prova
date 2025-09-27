class Libri::BulkActionsController < ApplicationController

  before_action :authenticate_user!

  def carrello
    @libri = Libro.where(id: params[:libro_ids])

    # Creare un nuovo documento ordine
    @documento = current_user.documenti.build(
      causale_id: Causale.find_by(sigla: 'ORDINE')&.id,
      tipo_documento: 'ordine',
      status: 'bozza'
    )

    if @documento.save
      # Aggiungere i libri come righe del documento
      @libri.each do |libro|
        @documento.documento_righe.create(
          articolo_type: 'Libro',
          articolo_id: libro.id,
          descrizione: libro.titolo,
          prezzo_unitario_cents: libro.prezzo_in_cents,
          quantita: 1
        )
      end

      redirect_to @documento, notice: "Nuovo ordine creato con #{@libri.count} libri"
    else
      redirect_back(fallback_location: libri_path, alert: "Errore nella creazione dell'ordine")
    end
  end

  def aggiungi
    @libri = Libro.where(id: params[:libro_ids])
    @documento_id = params[:documento_id]

    if @documento_id.present?
      @documento = current_user.documenti.find(@documento_id)

      @libri.each do |libro|
        # Controllo se il libro è già nel documento
        existing_riga = @documento.documento_righe.find_by(
          articolo_type: 'Libro',
          articolo_id: libro.id
        )

        if existing_riga
          # Se esiste, incrementa la quantità
          existing_riga.update(quantita: existing_riga.quantita + 1)
        else
          # Se non esiste, crea una nuova riga
          @documento.documento_righe.create(
            articolo_type: 'Libro',
            articolo_id: libro.id,
            descrizione: libro.titolo,
            prezzo_unitario_cents: libro.prezzo_in_cents,
            quantita: 1
          )
        end
      end

      redirect_to @documento, notice: "#{@libri.count} libri aggiunti all'ordine"
    else
      redirect_back(fallback_location: libri_path, alert: "Seleziona un ordine esistente")
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

end