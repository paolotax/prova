# Storia degli import MIUR letta nel contesto dell'account: solo le scuole
# dell'account, veri cambi vs spostamenti, promosse marcate "da rettificare"
# (design 2026-07-08-miur-import-runs-review-design.md). Admin-only.
class Miur::ImportRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @runs = Miur::ImportRun.adozioni
      .where(id: Miur::RettificheAccount.run_ids(Current.account))
      .order(completed_at: :desc).limit(50)

    codici = Current.account.scuole.where.not(codice_ministeriale: [nil, ""])
                    .distinct.pluck(:codice_ministeriale)
    scoped = Miur::ImportDiffScuola.where(import_run_id: @runs.map(&:id), codicescuola: codici)
    @scuole_per_run  = scoped.group(:import_run_id).count
    @aggiunte_per_run = scoped.group(:import_run_id).sum(:righe_aggiunte)
    @rimosse_per_run  = scoped.group(:import_run_id).sum(:righe_rimosse)
  end

  def show
    @run = Miur::ImportRun.adozioni.find(params[:id])
    @rettifiche = Miur::RettificheAccount.new(run: @run, account: Current.account)
  end

  private

  def require_admin
    redirect_to root_path, alert: "Solo per amministratori" unless Current.admin?
  end
end
