class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    @ritiro = Ritiro.new(@scuola)
  end

  def rientro
    riga = find_riga
    riga.update!(esito: :rientrato, processato_at: Time.current)
    redirect_to scuola_ritiro_path(@scuola)
  end

  def riapri
    riga = find_riga
    riga.update!(esito: nil, processato_at: nil)
    target = (params[:return_to] == "ritiro") ? scuola_ritiro_path(@scuola) : bolla_visione_path(riga.bolla_visione)
    redirect_to target
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
end
