module Accounts
  class ZoneController < ApplicationController
    before_action :authenticate_user!

    def index
      @account_zone = zone_ordinate
    end

    def new
      @regioni = ::Zona.order(:regione).select(:regione).distinct
      @province = if params[:regione].present?
                    ::Zona.where(regione: params[:regione]).order(:provincia).select(:provincia).distinct
                  else
                    []
                  end
      @gradi = TipoScuola::GRADI.reject { |g| g[1] == "I" }
    end

    def create
      regione = params[:regione].presence
      return redirect_to(accounts_configurazione_path) if regione.blank?

      Current.account.add_zone!(
        regione: regione,
        provincia: params[:provincia].presence,
        grado: params[:grado].presence
      )
      @account_zone = zone_ordinate
      @regioni = ::Zona.order(:regione).select(:regione).distinct

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to accounts_configurazione_path, notice: "Zona aggiunta!" }
      end
    end

    def destroy
      Current.account.zone.find(params[:id]).toggle_rimozione!

      @account_zone = zone_ordinate

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to accounts_configurazione_path, notice: "Zona rimossa!" }
      end
    end

    private

    def zone_ordinate
      Current.account.zone.order(:regione, :provincia, :grado)
    end
  end
end
