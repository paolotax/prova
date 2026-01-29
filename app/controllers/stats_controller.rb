# frozen_string_literal: true

class StatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stat, only: %i[show edit update destroy]

  def index
    @stats = policy_scope(Stat).order(:categoria, :position, :titolo)
    @stats = @stats.where(categoria: params[:categoria]) if params[:categoria].present?
  end

  def show
    authorize @stat
  end

  def new
    @stat = Stat.new
    authorize @stat
  end

  def edit
    authorize @stat
  end

  def create
    @stat = Stat.new(stat_params)
    authorize @stat

    if @stat.save
      redirect_to @stat, notice: "Statistica creata."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @stat

    if @stat.update(stat_params)
      redirect_to @stat, notice: "Statistica aggiornata."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @stat
    @stat.destroy!
    redirect_to stats_path, notice: "Statistica eliminata."
  end

  private

  def set_stat
    @stat = Stat.find(params[:id])
  end

  def stat_params
    params.require(:stat).permit(
      :titolo, :descrizione, :categoria, :anno,
      :testo, :raggruppa_per, :seleziona_campi,
      :ordina_per, :condizioni, :visible
    )
  end
end
