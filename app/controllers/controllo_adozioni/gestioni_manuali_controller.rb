class ControlloAdozioni::GestioniManualiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def create
    @scuola.update!(gestione_manuale: true)
    redirect_back fallback_location: controllo_adozioni_path(@scuola.codice_ministeriale),
                  notice: "#{@scuola.denominazione} in gestione manuale."
  end

  def destroy
    @scuola.update!(gestione_manuale: false)
    redirect_back fallback_location: controllo_adozioni_path(@scuola.codice_ministeriale),
                  notice: "Gestione manuale rimossa."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by(codice_ministeriale: params[:codicescuola])
    return if @scuola

    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                alert: "Scuola #{params[:codicescuola]} non trovata: codice già aggiornato o rimosso."
  end
end
