class ControlloAdozioni::PromozioniCiecheController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def new
    @anno_target = Miur.anno_corrente
    @da = @scuola.classi.attive.maximum(:anno_scolastico)
    if @anno_target.blank? || @da.blank?
      redirect_back fallback_location: controllo_adozioni_path(@scuola.codice_ministeriale),
                    alert: "Niente da promuovere."
      return
    end

    @anteprima = ControlloAdozioni::AnteprimaCieca.new(scuola: @scuola, da: @da, a: @anno_target)
  end

  def create
    a = Miur.anno_corrente
    da = @scuola.classi.attive.maximum(:anno_scolastico)
    if a.blank? || da.blank? || da >= a
      redirect_to controllo_adozioni_path(@scuola.codice_ministeriale), alert: "Niente da promuovere."
      return
    end

    ScuolaPromuoviCiecaJob.set(queue: :default).perform_later(@scuola, da: da, a: a)
    redirect_to controllo_adozioni_path(@scuola.codice_ministeriale, account_id: params[:account_id]),
                notice: "Promozione cieca avviata per #{@scuola.denominazione}."
  end

  private

  def set_scuola
    @scuola = current_account.scuole.find_by(codice_ministeriale: params[:codicescuola])
    return if @scuola

    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                alert: "Scuola #{params[:codicescuola]} non trovata: codice già aggiornato o rimosso."
  end
end
