class Zone::ImportazioniController < ApplicationController
  before_action :authenticate_user!

  def create
    account = Current.account

    account.account_zone.where(stato: "da_rimuovere").find_each do |zona|
      zona.update!(stato: "pulizia")
      CleanupZonaJob.perform_later(zona)
    end

    account.account_zone.pronte.find_each do |zona|
      zona.update!(stato: "importazione")
      ImportScuolePerZonaJob.perform_later(zona)
    end

    @account_zone = account.account_zone.order(:regione, :provincia, :grado)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to configurazione_path, notice: "Aggiornamento in corso..." }
    end
  end
end
