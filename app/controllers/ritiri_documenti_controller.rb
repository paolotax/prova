class RitiriDocumentiController < ApplicationController
  before_action :set_scuola

  def create
    if righe.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una riga." and return
    end

    Documento.transaction do
      righe_finali = applica_split_fascicoli(righe)

      @documento = Ritiro::CreaDocumento.new(
        righe: righe_finali,
        causale: causale,
        clientable: clientable,
        data: params[:data_documento]
      ).call
    end

    redirect_to scuola_ritiro_path(@scuola),
                notice: "Documento #{@documento.causale.causale} creato (#{@documento.documento_righe.count} righe)."
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

  # Per il caso "Mancante" su confezione: per ogni riga selezionata che e' una
  # confezione con fascicoli specificati nei params, splitta in N righe-fascicolo
  # mancanti e chiude la confezione con l'esito scelto. Le righe-fascicolo nuove
  # sostituiscono la riga-confezione nel documento.
  def applica_split_fascicoli(righe_iniziali)
    return righe_iniziali if causale&.causale != "Mancante"
    return righe_iniziali if params[:fascicoli_per_riga].blank?

    righe_iniziali.flat_map do |bv_riga|
      info = params[:fascicoli_per_riga][bv_riga.id.to_s]
      next bv_riga if info.blank?

      fascicolo_ids = Array(info[:fascicolo_ids]).reject(&:blank?)
      next bv_riga if fascicolo_ids.empty?

      fascicoli = bv_riga.libro.fascicoli.where(id: fascicolo_ids)
      esito = (info[:esito_confezione].presence || "rientrato").to_sym
      bv_riga.splitta_in_fascicoli!(fascicoli, esito_confezione: esito)
    end
  end
end
