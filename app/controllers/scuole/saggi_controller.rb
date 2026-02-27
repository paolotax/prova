class Scuole::SaggiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def index
    @saggi = @scuola.saggi
      .includes(:libro, :destinatario)
      .order(created_at: :desc)
    @da_scaricare_count = @scuola.saggi.da_scaricare.count
  end

  def create
    @saggio = @scuola.saggi.build(saggio_params)
    @saggio.destinatario = find_destinatario if params[:destinatario_value].present?

    if @saggio.save
      redirect_to scuola_path(@scuola)
    else
      redirect_to scuola_path(@scuola), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    @saggio = @scuola.saggi.find(params[:id])
    if @saggio.update(saggio_params)
      redirect_to scuola_path(@scuola)
    else
      redirect_to scuola_path(@scuola), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio = @scuola.saggi.find(params[:id])
    @saggio.destroy
    redirect_to scuola_path(@scuola)
  end

  def genera_scarico
    service = Saggio::ScaricoCampionario.new(@scuola)
    documento = service.genera!

    if documento
      redirect_to scuola_path(@scuola), notice: "Scarico campionario generato"
    else
      redirect_to scuola_path(@scuola), alert: "Nessun saggio da scaricare"
    end
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def saggio_params
    params.require(:saggio).permit(:libro_id, :quantita, :stato, :note)
  end

  def find_destinatario
    klass_name, id = params[:destinatario_value].split(":")
    klass = klass_name.safe_constantize
    return nil unless klass && %w[Persona Classe].include?(klass_name)
    klass.find_by(id: id)
  end
end
