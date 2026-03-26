class Persone::SaggiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_persona
  before_action :set_saggio, only: [:update, :destroy]

  def create
    @saggio = @persona.saggi.build(saggio_params)
    @saggio.scuola = @persona.scuola

    if @saggio.save
      respond_to do |format|
        format.turbo_stream { render_saggi_stream }
        format.html { redirect_to persona_path(@persona) }
      end
    else
      redirect_to persona_path(@persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    if @saggio.update(saggio_params)
      respond_to do |format|
        format.turbo_stream { render_saggi_stream }
        format.html { redirect_to persona_path(@persona) }
      end
    else
      redirect_to persona_path(@persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio.destroy
    respond_to do |format|
      format.turbo_stream { render_saggi_stream }
      format.html { redirect_to persona_path(@persona) }
    end
  end

  private

  def set_persona
    @persona = Current.account.persone.find(params[:persona_id])
  end

  def set_saggio
    @saggio = @persona.saggi.find(params[:id])
  end

  def saggio_params
    params.require(:saggio).permit(:libro_id, :quantita, :stato, :note, :data_consegna, :data_prenotazione)
  end

  def render_saggi_stream
    @persona.reload
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@persona, :saggi),
      partial: "persone/container/saggi",
      locals: { persona: @persona }
    )
  end
end
