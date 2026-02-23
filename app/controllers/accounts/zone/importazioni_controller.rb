module Accounts
  class Zone::ImportazioniController < ApplicationController
    before_action :authenticate_user!

    def create
      account = Current.account

      account.zone.where(stato: "da_rimuovere").find_each do |zona|
        zona.update!(stato: "pulizia")
        CleanupZonaJob.perform_later(zona)
      end

      account.zone.pronte.find_each do |zona|
        zona.update!(stato: "importazione")
        ImportScuolePerZonaJob.perform_later(zona)
      end

      @account_zone = account.zone.order(:regione, :provincia, :grado)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to configurazione_path, notice: "Aggiornamento in corso..." }
      end
    end
  end
end
