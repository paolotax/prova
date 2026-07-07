# POST controllo_adozioni/anomalie — ricostruisce da zero controllo_anomalie
# (tabella globale) dallo snapshot MIUR corrente.
class ControlloAdozioni::AnomalieController < ControlloAdozioni::BaseController
  def create
    RicalcolaAnomalieJob.perform_later
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                notice: "Ricalcolo delle anomalie avviato."
  end
end
