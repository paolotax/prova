class RitiriDocumentiController < ApplicationController
  before_action :set_scuola

  def create
    if righe.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una riga." and return
    end

    documento = Ritiro::CreaDocumento.new(
      righe: righe,
      causale: causale,
      clientable: clientable,
      data: params[:data_documento]
    ).call

    redirect_to scuola_ritiro_path(@scuola),
                notice: "Documento #{documento.causale.causale} creato (#{documento.documento_righe.count} righe)."
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to scuola_ritiro_path(@scuola), alert: "Errore: #{e.message}"
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def righe
    @righe ||= begin
      ids = Array(params[:bolla_visione_riga_ids]).reject(&:blank?)
      Current.account.bolla_visione_righe
        .where(id: ids, processato_at: nil)
        .includes(:libro)
    end
  end

  def causale
    Causale.find_by(id: params[:causale_id])
  end

  def clientable
    klass = params[:clientable_type].constantize
    klass.find(params[:clientable_id])
  end
end
