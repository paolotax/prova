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

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def build_gruppo_lookup(bolle)
    collana_ids = bolle.map(&:collana_id).uniq
    CollanaLibro.where(collana_id: collana_ids)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
