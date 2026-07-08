# Bottone "Ri-reconcilia questa provincia": convenienza manuale (MAI automatico).
# Accoda il reconcile per l'account corrente; le protezioni sul lavoro utente
# sono nel Reconciler stesso (ON CONFLICT DO NOTHING + orfane protette).
class Miur::ImportRuns::ReconcilesController < ApplicationController
  before_action :authenticate_user!
  # Prima di qualunque find/params.require: un member non deve poter sondare
  # l'esistenza dei run (404 vs 400) né ricevere errori diversi da 403.
  before_action :require_admin

  def create
    run = Miur::ImportRun.adozioni.find(params[:import_run_id])
    provincia = params.require(:provincia)

    ReconcileAdozioniJob.perform_later(Current.account, provincia: provincia,
                                       anno: run.anno_scolastico)
    redirect_to miur_import_run_path(run, provincia: provincia),
                notice: "Reconcile accodato per #{provincia}"
  end

  private

  def require_admin
    head :forbidden unless Current.admin?
  end
end
