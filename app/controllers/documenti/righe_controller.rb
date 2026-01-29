# frozen_string_literal: true

class Documenti::RigheController < ApplicationController
  include DocumentoScoped

  # POST /documenti/:documento_id/righe (bulk update via JSON)
  def create
    righe_params = params.require(:righe)

    ActiveRecord::Base.transaction do
      righe_params.each do |riga_param|
        riga_param = riga_param.permit(:documento_riga_id, :riga_id, :libro_id, :quantita, :prezzo_cents, :sconto, :_destroy, :_isNew)

        if riga_param[:_destroy]
          delete_riga(riga_param)
        elsif riga_param[:_isNew] || riga_param[:documento_riga_id].blank?
          create_riga(riga_param)
        else
          update_riga(riga_param)
        end
      end
    end

    @documento.reload
    @documento.ricalcola_totali!

    render json: {
      success: true,
      righe: righe_as_json
    }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def delete_riga(params)
    return if params[:documento_riga_id].blank?
    doc_riga = @documento.documento_righe.find_by(id: params[:documento_riga_id])
    doc_riga&.destroy
  end

  def create_riga(params)
    riga = Riga.create!(
      libro_id: params[:libro_id],
      quantita: params[:quantita] || 1,
      prezzo_cents: params[:prezzo_cents] || 0,
      sconto: params[:sconto] || 0
    )
    @documento.documento_righe.create!(riga: riga)
  end

  def update_riga(params)
    doc_riga = @documento.documento_righe.find_by(id: params[:documento_riga_id])
    return unless doc_riga&.riga

    doc_riga.riga.update!(
      libro_id: params[:libro_id],
      quantita: params[:quantita] || 1,
      prezzo_cents: params[:prezzo_cents] || 0,
      sconto: params[:sconto] || 0
    )
  end

  def righe_as_json
    @documento.documento_righe.includes(riga: :libro).map do |doc_riga|
      riga = doc_riga.riga
      {
        documento_riga_id: doc_riga.id,
        riga_id: riga.id,
        libro_id: riga.libro_id,
        libro: {
          id: riga.libro&.id,
          titolo: riga.libro&.titolo,
          codice_isbn: riga.libro&.codice_isbn
        },
        titolo: riga.libro&.titolo,
        codice_isbn: riga.libro&.codice_isbn,
        quantita: riga.quantita,
        prezzo_cents: riga.prezzo_cents,
        sconto: riga.sconto
      }
    end
  end
end
