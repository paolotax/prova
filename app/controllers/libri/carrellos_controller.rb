# frozen_string_literal: true

class Libri::CarrellosController < ApplicationController
  # POST /libri/carrello - crea nuovo documento con libri selezionati
  def create
    @libri = current_account.libri.where(id: params[:libro_ids])

    @documento = current_user.documenti.build(
      data_documento: Date.today
    )

    if @documento.save
      @libri.each do |libro|
        cliente = @documento.clientable if @documento.clientable_type == "Cliente"
        scuola = @documento.clientable if @documento.clientable_type == "Scuola"
        sconto = Sconto.sconto_per_libro(libro: libro, cliente: cliente, scuola: scuola, user: current_user)

        riga = Riga.create!(
          libro_id: libro.id,
          prezzo_cents: libro.prezzo_in_cents,
          quantita: 1,
          sconto: sconto
        )
        @documento.documento_righe.create!(riga: riga)
      end

      redirect_to @documento, notice: "Nuovo ordine creato con #{@libri.count} libri"
    else
      redirect_to libri_path, alert: "Errore nella creazione dell'ordine"
    end
  end

  # PATCH /libri/carrello - aggiunge libri a documento esistente
  def update
    @libri = current_account.libri.where(id: params[:libro_ids])

    @documento = if params[:documento_id].present?
      current_user.documenti.find(params[:documento_id])
    else
      current_user.documenti.order(data_documento: :desc, numero_documento: :desc).first
    end

    unless @documento
      redirect_to libri_path, alert: "Nessun ordine disponibile. Crea prima un nuovo ordine."
      return
    end

    @libri.each do |libro|
      cliente = @documento.clientable if @documento.clientable_type == "Cliente"
      scuola = @documento.clientable if @documento.clientable_type == "Scuola"
      sconto = Sconto.sconto_per_libro(libro: libro, cliente: cliente, scuola: scuola, user: current_user)

      riga = Riga.create!(
        libro_id: libro.id,
        prezzo_cents: libro.prezzo_in_cents,
        quantita: 1,
        sconto: sconto
      )
      @documento.documento_righe.create!(riga: riga)
    end

    redirect_to @documento, notice: "#{@libri.count} libri aggiunti all'ordine ##{@documento.numero_documento}"
  end
end
