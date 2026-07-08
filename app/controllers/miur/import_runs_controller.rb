# Storia degli import MIUR con drill-down del diff (pagina standalone, design
# 2026-07-08-miur-import-diff-design.md). Dati MIUR-globali (nessuno scope
# account sui dati), ma la pagina vive nel contesto account: solo admin.
class Miur::ImportRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @runs = Miur::ImportRun.adozioni.order(completed_at: :desc).limit(50)
    # Conteggi diff per run in un colpo solo (evita N+1 sulla lista).
    @conteggi = Miur::ImportDiffScuola
      .where(import_run_id: @runs.map(&:id))
      .group(:import_run_id, :categoria).count
  end

  def show
    @run = Miur::ImportRun.adozioni.find(params[:id])
    @provincia = params[:provincia].presence

    scuole = @run.diff_scuole.per_provincia(@provincia)
    @riepilogo_province = @run.diff_scuole
      .group(:provincia, :categoria)
      .pluck(:provincia, :categoria, Arel.sql("COUNT(*)"),
             Arel.sql("SUM(righe_aggiunte)"), Arel.sql("SUM(righe_rimosse)"))
    @esistenti = scuole.esistenti.order(Arel.sql("righe_aggiunte + righe_rimosse DESC"))
    @nuove_count = scuole.nuove.count
    @sparite = scuole.sparite.order(:provincia, :codicescuola)

    # Dettaglio righe della scuola selezionata (drill)
    if params[:codicescuola].present?
      @scuola_focus = params[:codicescuola]
      @righe = @run.diff_righe.where(codicescuola: @scuola_focus)
                   .order(:annocorso, :sezioneanno, :disciplina, :segno)
      @sostituzioni = sostituzioni(@righe)
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "Solo per amministratori" unless Current.admin?
  end

  # "Sostituzione da verificare": stessa classe+disciplina con sia '+' che '-'
  # (il MIUR ha cambiato libro). Derivata a lettura, non persistita.
  def sostituzioni(righe)
    righe.group_by { |r| [r.annocorso, r.sezioneanno, r.combinazione, r.disciplina] }
         .select { |_, rr| rr.map(&:segno).uniq.sort == ["+", "-"] }
  end
end
