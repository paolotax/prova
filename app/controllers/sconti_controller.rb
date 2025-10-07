class ScontiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scontabile, only: [:index, :new, :create]
  before_action :set_sconto, only: [:edit, :update, :destroy]

  def index
    @sconti = if @scontabile
                @scontabile.sconti.where(user: Current.user).includes(:categoria).order(data_inizio: :desc)
              else
                Current.user.sconti.includes(:categoria, :scontabile).order(data_inizio: :desc)
              end
  end

  def new
    @sconto = if @scontabile
                @scontabile.sconti.build(user: Current.user)
              else
                Current.user.sconti.build
              end
    @sconto.tipo_sconto = determine_tipo_sconto
  end

  def create
    @sconto = if @scontabile
                @scontabile.sconti.build(sconto_params.merge(user: Current.user))
              else
                Current.user.sconti.build(sconto_params)
              end

    @sconto.tipo_sconto = determine_tipo_sconto if @scontabile

    if @sconto.save
      redirect_to redirect_path, notice: 'Sconto creato con successo.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @sconto.update(sconto_params)
      redirect_to redirect_path, notice: 'Sconto aggiornato con successo.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @scontabile = @sconto.scontabile
    @sconto.destroy
    redirect_to redirect_path, notice: 'Sconto eliminato con successo.'
  end

  private

  def set_scontabile
    if params[:cliente_id]
      @scontabile = Current.user.clienti.find(params[:cliente_id])
    elsif params[:editore_id]
      @scontabile = Current.user.editori.find(params[:editore_id])
    elsif params[:import_scuola_id]
      @scontabile = Current.user.import_scuole.find(params[:import_scuola_id])
    end
  end

  def set_sconto
    @sconto = Current.user.sconti.find(params[:id])
    @scontabile = @sconto.scontabile
  end

  def sconto_params
    params.require(:sconto).permit(:categoria_id, :percentuale_sconto, :data_inizio, :data_fine, :tipo_sconto, :scontabile_type, :scontabile_id)
  end

  def determine_tipo_sconto
    return :acquisto if @scontabile.is_a?(Editore)
    return :vendita if @scontabile.is_a?(Cliente) || @scontabile.is_a?(ImportScuola)
    params[:tipo_sconto] || :vendita
  end

  def redirect_path
    if @scontabile
      polymorphic_path([@scontabile, :sconti])
    else
      sconti_path
    end
  end
end
