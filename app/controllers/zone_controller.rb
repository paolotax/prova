class ZoneController < ApplicationController
  before_action :authenticate_user!

  def index
    @account_zone = Current.account.account_zone.order(:provincia, :grado)
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = []
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
    @tipi = []
  end

  def select_zone
    @regioni = Zona.order(:regione).select(:regione).distinct
    @province = Zona.where(regione: params[:regione].presence)
                    .order(:provincia).select(:provincia).distinct
    @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
    @tipi = if params[:grado].present?
              TipoScuola.where(grado: params[:grado]).order(:tipo).select(:tipo).distinct
            else
              []
            end
  end

  def assegna_scuole
    return if params[:hregione].blank?

    @account_zona = Current.account.account_zone.find_or_initialize_by(
      provincia: params[:hprovincia],
      grado: params[:hgrado]
    )
    @account_zona.regione = params[:hregione]
    @account_zona.anno_scolastico ||= "2025/2026"
    @account_zona.stato = "conteggio" if @account_zona.new_record?
    @account_zona.save!

    @account_zone = Current.account.account_zone.order(:provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Zona aggiunta!" }
    end
  end

  def importa_scuole
    account = Current.account

    # Cleanup zone da rimuovere
    account.account_zone.where(stato: "da_rimuovere").find_each do |zona|
      zona.update!(stato: "pulizia")
      CleanupZonaJob.perform_later(zona)
    end

    # Import zone pronte
    account.account_zone.pronte.find_each do |zona|
      zona.update!(stato: "importazione")
      ImportScuolePerZonaJob.perform_later(zona)
    end

    @account_zone = account.account_zone.order(:provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Aggiornamento in corso..." }
    end
  end

  def rimuovi_scuole
    @account_zona = Current.account.account_zone.find(params[:id])

    if @account_zona.stato.in?(%w[pronta conteggio])
      @account_zona.destroy!
    else
      @account_zona.update!(stato: "da_rimuovere")
    end

    @account_zone = Current.account.account_zone.order(:provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Zona rimossa!" }
    end
  end
end
