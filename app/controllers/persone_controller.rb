class PersoneController < ApplicationController
  def show
    @persona = Current.account.persone.find(params[:id])

    if @persona.scuola.present?
      redirect_to scuola_persona_path(@persona.scuola, @persona), status: :moved_permanently
      return
    end

    @appunti = @persona.appunti.includes(:entry).order(created_at: :desc)
  end
end
