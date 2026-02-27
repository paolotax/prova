class Scuole::Persone::SaggiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola
  before_action :set_persona
  before_action :set_saggio, only: [:update, :destroy]

  def create
    @saggio = @persona.saggi.build(saggio_params)
    @saggio.scuola = @scuola

    if @saggio.save
      redirect_to scuola_persona_path(@scuola, @persona)
    else
      redirect_to scuola_persona_path(@scuola, @persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    if @saggio.update(saggio_params)
      redirect_to scuola_persona_path(@scuola, @persona)
    else
      redirect_to scuola_persona_path(@scuola, @persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio.destroy
    redirect_to scuola_persona_path(@scuola, @persona)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def set_persona
    @persona = @scuola.persone.find(params[:persona_id])
  end

  def set_saggio
    @saggio = @persona.saggi.find(params[:id])
  end

  def saggio_params
    params.require(:saggio).permit(:libro_id, :quantita, :stato, :note)
  end
end
