class GiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro, only: %i[show edit update destroy copia]

  def index
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)
    respond_to do |format|
      format.html
      format.json
    end
  end

  def show
    return respond_to { |format| format.json } if request.format.json?

    @tappe_per_giorno  = @giro.tappe_per_giorno
    @tappe_per_area    = @giro.tappe.da_programmare.raggruppate_per_area
    @planner_total     = @tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }
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

    if @giro.save
      @giro.broadcast_append_later_to [current_user, "giri"], target: "giri-lista"
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Giro creato." }
        format.html { redirect_to giri_url, notice: "Giro creato." }
        format.json { render :show, status: :created, location: @giro }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @giro.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @giro.assign_attributes(giro_params)

    if @giro.save
      @giro.broadcast_replace_later_to [current_user, "giri"]
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Giro modificato." }
        format.html { redirect_to @giro, notice: "Giro modificato." }
        format.json { render :show, status: :ok, location: @giro }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @giro.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @giro.destroy!
    respond_to do |format|
      format.html { redirect_to giri_path, notice: "Giro eliminato." }
      format.json { head :no_content }
    end
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:id])
  end

  def giro_params
    params.require(:giro).permit(:titolo, :descrizione, :collana_id, :iniziato_il, :finito_il, :color, conditions: [])
  end
end
