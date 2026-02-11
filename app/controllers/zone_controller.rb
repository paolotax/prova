class ZoneController < ApplicationController
  before_action :authenticate_user!

  def index
    @account_zone = Current.account.account_zone.order(:provincia, :grado)
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = []
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
  end

  def select_zone
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = Zona.where(regione: params[:regione].presence)
                    .order(:provincia).select(:provincia).distinct
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
  end

  def assegna_scuole
    return if params[:hregione].blank?

    @account_zona = Current.account.account_zone.find_or_initialize_by(
      provincia: params[:hprovincia],
      grado: params[:hgrado]
    )
    @account_zona.regione = params[:hregione]
    @account_zona.anno_scolastico ||= "2025/2026"
    @account_zona.save!

    @account_zone = Current.account.account_zone.order(:provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to zone_path, notice: "Zona aggiunta!" }
    end
  end

  def rimuovi_scuole
    @account_zona = Current.account.account_zone.find(params[:id])
    @account_zona.destroy

    @account_zone = Current.account.account_zone.order(:provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to zone_path, notice: "Zona rimossa!" }
    end
  end
end
