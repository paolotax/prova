class GiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro, only: %i[show edit update destroy planner copia]

  def index
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)
  end

  def show
    @settimane = genera_settimane(@giro.iniziato_il, @giro.finito_il)
    @tappe_per_giorno = @giro.tappe
      .con_data_tappa
      .includes(:tappable, :giri)
      .group_by(&:data_tappa)
    @tappe_per_area = planner_tappe_per_area
    @planner_total = @tappe_per_area.flat_map { |_, dirs| dirs.flat_map(&:last) }.size

    @tappe_totali = @giro.tappe.size
    @tappe_completate = @giro.tappe.completate.size
    @giorni_timeline = genera_giorni_timeline(@tappe_per_giorno)
  end

  def planner
    tappe_per_area = planner_tappe_per_area
    total_count = tappe_per_area.flat_map { |_, dirs| dirs.flat_map(&:last) }.size

    render partial: "giri/planner", locals: {
      giro: @giro,
      tappe_per_area: tappe_per_area,
      total_count: total_count
    }
  end

  def copia
    @altri_giri = current_user.giri.where.not(id: @giro.id).order(created_at: :desc)
  end

  def new
    @giro = current_user.giri.build
    @collane = Current.account.collane.ordered
  end

  def edit
    @collane = Current.account.collane.ordered
  end

  def create
    @giro = current_user.giri.build(giro_params)
    set_default_finito_il(@giro)

    if @giro.save
      @giro.broadcast_append_later_to [current_user, "giri"], target: "giri-lista"
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Giro creato." }
        format.html { redirect_to giri_url, notice: "Giro creato." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @giro.assign_attributes(giro_params)
    set_default_finito_il(@giro)

    if @giro.save
      @giro.broadcast_replace_later_to [current_user, "giri"]
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Giro modificato." }
        format.html { redirect_to @giro, notice: "Giro modificato." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @giro.broadcast_remove_to [current_user, "giri"]
    @giro.destroy!

    respond_to do |format|
      format.turbo_stream { flash.now[:alert] = "Giro eliminato." }
      format.html { redirect_to giri_url, alert: "Giro eliminato." }
    end
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:id])
  end

  def set_default_finito_il(giro)
    return unless giro.iniziato_il.present?
    return if giro.finito_il.present? && giro.finito_il >= giro.iniziato_il

    giro.finito_il = giro.iniziato_il + 4.weeks
  end

  def giro_params
    params.require(:giro).permit(:titolo, :descrizione, :collana_id, :iniziato_il, :finito_il, :color, conditions: [], excluded_ids: [])
  end

  def genera_settimane(dal, al)
    return [] unless dal && al
    dal_date = dal.to_date
    al_date = al.to_date
    return [] if al_date < dal_date || (al_date - dal_date).to_i > 365
    primo_lunedi = dal_date.beginning_of_week
    ultimo_dom = al_date.end_of_week
    (primo_lunedi..ultimo_dom).group_by { |d| d.beginning_of_week }.values
  end

  def genera_giorni_timeline(tappe_per_giorno)
    oggi = Date.current
    tappe_per_giorno.transform_keys { |k| k.to_date }.sort.map do |date, tappe|
      { date: date, count: tappe.size, today: date == oggi, past: date < oggi }
    end
  end

  def planner_tappe_per_area
    tappe = @giro.tappe
      .da_programmare
      .where(tappable_type: "Scuola")
      .includes(:giri)
      .preload(:tappable)
      .to_a

    # Preload direzione for all Scuola tappables to avoid N+1
    scuole = tappe.map(&:tappable).compact.uniq
    ActiveRecord::Associations::Preloader.new(records: scuole, associations: :direzione).call

    tappe
      .group_by { |t| t.tappable.area.presence || "Senza area" }
      .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
      .map { |area, area_tappe|
        direzioni = area_tappe
          .group_by { |t| t.tappable.direzione || t.tappable }
          .sort_by { |dir, _| dir.denominazione.to_s }
        [area, direzioni]
      }
  end
end
