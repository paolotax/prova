# frozen_string_literal: true

class StatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_stat, only: %i[show edit update destroy]

  CATEGORIE_VISIBILI = %w[utenti editori province titoli operativo].freeze

  def index
    base = policy_scope(Stat)

    if current_user.admin?
      stati = Array(params[:stati]).presence || %w[produzione lab]
      stati &= Stat::STATI
      @stati_filtro = stati
      base = base.where(stato: stati) if stati.any?
    else
      @stati_filtro = %w[produzione]
    end

    @counts_per_stato = current_user.admin? ? Stat.group(:stato).count : nil
    @counts_per_categoria = base.group(:categoria).count
    @stats_in_errore = current_user.admin? ? Stat.produzione.con_errore.count : 0

    @stats = base.order(:categoria, :position, :titolo)
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
