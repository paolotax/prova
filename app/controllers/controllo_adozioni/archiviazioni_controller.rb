class ControlloAdozioni::ArchiviazioniController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def create
    @scuola.archivia_soppressa!
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale, account_id: params[:account_id]),
                notice: "#{@scuola.denominazione} archiviata (soppressa)."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by(codice_ministeriale: params[:codicescuola])
    return if @scuola

    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                alert: "Scuola #{params[:codicescuola]} non trovata: codice già aggiornato o rimosso."
  end
end
