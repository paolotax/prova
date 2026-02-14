module Scuole
  module Persone
    class PersonaClassiController < ApplicationController
      before_action :set_scuola
      before_action :set_persona

      def destroy
        @persona_classe = @persona.persona_classi.find(params[:id])
        @persona_classe.destroy

        redirect_to scuola_persona_path(@scuola, @persona), notice: "Classe scollegata"
      end

      private

      def set_scuola
        @scuola = Scuola.find(params[:scuola_id])
      end

      def set_persona
        @persona = @scuola.persone.find(params[:persona_id])
      end
    end
  end
end
