# Bottone "Applica le rettifiche": convenienza manuale (MAI automatico).
# Fan-out di ReconcileAdozioniJob sulle sole province (formato scuole account)
# delle scuole PROMOSSE toccate dal run — ricalcolate server-side, mai da params.
# Le protezioni sul lavoro utente sono nel Reconciler (DO NOTHING + orfane protette).
class Miur::ImportRuns::ReconcilesController < ApplicationController
  before_action :authenticate_user!
  # Prima di qualunque find: un member non deve poter sondare l'esistenza dei run.
  before_action :require_admin

  def create
    run = Miur::ImportRun.adozioni.find(params[:import_run_id])
    province = Miur::RettificheAccount.new(run: run, account: Current.account).province_promosse

    province.each do |provincia|
      ReconcileAdozioniJob.perform_later(Current.account, provincia: provincia,
                                         anno: run.anno_scolastico)
    end
    notice = province.any? ? "Reconcile accodato per: #{province.join(', ')}"
                           : "Nessuna scuola promossa da rettificare"
    redirect_to miur_import_run_path(run), notice: notice
  end

  private

  def require_admin
    head :forbidden unless Current.admin?
  end
end
