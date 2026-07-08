# Bottone "Ri-reconcilia questa provincia": convenienza manuale (MAI automatico).
# Accoda il reconcile per l'account corrente; le protezioni sul lavoro utente
# sono nel Reconciler stesso (ON CONFLICT DO NOTHING + orfane protette).
class Miur::ImportRuns::ReconcilesController < ApplicationController
  before_action :authenticate_user!

  def create
    run = Miur::ImportRun.adozioni.find(params[:import_run_id])
    provincia = params.require(:provincia)
    head :forbidden and return unless Current.admin?

    ReconcileAdozioniJob.perform_later(Current.account, provincia: provincia,
                                       anno: run.anno_scolastico)
    redirect_to miur_import_run_path(run, provincia: provincia),
                notice: "Reconcile accodato per #{provincia}"
  end
end
