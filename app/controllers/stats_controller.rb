class StatsController < ApplicationController

  before_action :authenticate_user!
  before_action :set_stat, only: %i[ show edit update destroy execute ]

  def index
    @stats = Stat.all
    @stats = @stats.where(categoria: params[:categoria]) if params[:categoria].present?
    @stats = @stats.order(:titolo)
  end

  def show
  end

  def new
    @stat = Stat.new
  end

  def edit
  end

  def execute
    @miei_editori = current_user.miei_editori

    @result = @stat.execute current_user
    respond_to do |format|
      format.html
      format.xlsx
    end
  end

  def create
    @stat = Stat.new(stat_params)

    respond_to do |format|
      if @stat.save
        format.html { redirect_to @stat, notice: "Stat creata." }
        format.json { render :show, status: :created, location: @stat }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @stat.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @stat.update(stat_params)
        format.html { redirect_to @stat, notice: "Stat aggiornata!" }
        format.json { render :show, status: :ok, location: @stat }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @stat.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @stat.destroy!

    respond_to do |format|
      format.html { redirect_to stats_url, alert: "Stat eliminata!" }
      format.json { head :no_content }
    end
  end

  private

    def set_stat
      @stat = Stat.find(params[:id])
    end

    def stat_params
      params.require(:stat).permit(:descrizione, :seleziona_campi, :raggruppa_per, :ordina_per, :condizioni, :testo, :titolo, :categoria, :anno)
    end
end
