class Mandati::Gruppi::DisdettaController < ApplicationController
  before_action :authenticate_user!

  def create
    bulk_scope.update_all(disdetta: true)
    replace_mandati_list
  end

  def destroy
    bulk_scope.update_all(disdetta: false)
    replace_mandati_list
  end

  private

  def bulk_scope
    Current.account.mandati
      .joins(:editore)
      .where(provincia: params[:provincia], editori: { gruppo: params[:gruppi_id] })
  end

  def replace_mandati_list
    @mandati = Current.account.mandati.includes(:editore).order("editori.gruppo, editori.editore")

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("account-editori", partial: "mandati/mandati_list", locals: { mandati: @mandati }) }
      format.html { redirect_to configurazione_path }
    end
  end
end
