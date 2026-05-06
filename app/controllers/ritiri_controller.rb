class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    @bolle = @scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(bolla_visione_righe: { processato_at: nil })
      .includes(:collana)
      .distinct
      .ordered

    @righe_per_bolla = @bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe.aperte.includes(:libro).order(:position)
    end

    # Letto da _lista (Task 6) e _crea_bolle_da_collane (Task 12) per raggruppare per CollanaLibro.gruppo
    @gruppo_per_libro_e_collana = build_gruppo_lookup(@bolle)
  end

  def rientro
    riga = find_riga
    riga.update!(esito: :rientrato, processato_at: Time.current)
    respond_to do |format|
      format.html { redirect_to scuola_ritiro_path(@scuola) }
      format.turbo_stream { render turbo_stream: turbo_stream.remove(ActionView::RecordIdentifier.dom_id(riga)) }
    end
  end

  def riapri
    riga = find_riga
    BollaVisioneRiga.transaction do
      doc_riga = riga.documento_riga
      riga.update!(esito: nil, processato_at: nil, documento_riga_id: nil)
      if doc_riga.present?
        documento = doc_riga.documento
        doc_riga.destroy
        documento.destroy if documento.documento_righe.reload.empty?
      end
    end
    redirect_to bolla_visione_path(riga.bolla_visione)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def find_riga
    Current.account.bolla_visione_righe
      .joins(:bolla_visione)
      .where(bolle_visione: { scuola_id: @scuola.id })
      .find(params[:id])
  end

  def build_gruppo_lookup(bolle)
    collana_ids = bolle.map(&:collana_id).uniq
    CollanaLibro.where(collana_id: collana_ids)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
