module Persone
  class PersonaClassiController < ApplicationController
    before_action :set_persona

    def destroy
      @persona_classe = @persona.persona_classi.find(params[:id])
      @persona_classe.destroy

      redirect_to persona_path(@persona), notice: "Classe scollegata"
    end

    private

    def set_persona
      @persona = Current.account.persone.find(params[:persona_id])
    end
  end
end
