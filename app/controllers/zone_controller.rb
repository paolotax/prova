class ZoneController < ApplicationController
  before_action :authenticate_user!

  def index
    @account_zone = Current.account.account_zone.order(:regione, :provincia, :grado)
  end

  # GET /zone/new — cascading selects (turbo_frame :zone_select)
  def new
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = if params[:regione].present?
                  Zona.where(regione: params[:regione]).order(:provincia).select(:provincia).distinct
                else
                  []
                end
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
  end

  def create
    regione = params[:regione].presence
    return redirect_to(configurazione_path) if regione.blank?

    Current.account.add_zone!(
      regione: regione,
      provincia: params[:provincia].presence,
      grado: params[:grado].presence
    )
    @account_zone = Current.account.account_zone.order(:regione, :provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Zona aggiunta!" }
    end
  end

  def destroy
    @account_zona = Current.account.account_zone.find(params[:id])

    case @account_zona.stato
    when "pronta", "conteggio"
      @account_zona.destroy!
    when "da_rimuovere"
      @account_zona.update!(stato: "attiva")
    else
      @account_zona.update!(stato: "da_rimuovere")
    end

    @account_zone = Current.account.account_zone.order(:regione, :provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Zona rimossa!" }
    end
  end
end
