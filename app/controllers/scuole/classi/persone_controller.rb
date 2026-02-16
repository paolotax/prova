module Scuole
  module Classi
    class PersoneController < ApplicationController
      before_action :set_scuola
      before_action :set_classe

      def new
        @assigned = @classe.persone.includes(:persona_classi).order(:cognome, :nome)
        @available = @scuola.persone.docente
          .where.not(id: @classe.persone.select(:id))
          .order(:cognome, :nome)
      end

      def create
        if params[:persona_id].present?
          # Assign existing persona
          persona = @scuola.persone.find(params[:persona_id])
          @classe.persona_classi.find_or_create_by!(persona: persona) do |pc|
            pc.materia = params[:materia]
          end
        else
          # Create new persona and assign
          persona = @scuola.persone.create!(
            cognome: params[:cognome],
            nome: params[:nome],
            ruolo: :docente,
            account: Current.account
          )
          @classe.persona_classi.create!(persona: persona, materia: params[:materia])
        end

        respond_to do |format|
          format.turbo_stream { load_lists }
          format.html { redirect_to scuola_classe_path(@scuola, @classe) }
        end
      end

      def destroy
        persona_classe = @classe.persona_classi.find(params[:id])
        persona_classe.destroy

        respond_to do |format|
          format.turbo_stream { load_lists }
          format.html { redirect_to scuola_classe_path(@scuola, @classe) }
        end
      end

      private

      def set_scuola
        @scuola = Current.account.scuole.find(params[:scuola_id])
      end

      def set_classe
        @classe = @scuola.classi.find(params[:classe_id])
      end

      def load_lists
        @assigned = @classe.persone.includes(:persona_classi).order(:cognome, :nome)
        @available = @scuola.persone.docente
          .where.not(id: @classe.persone.select(:id))
          .order(:cognome, :nome)
      end
    end
  end
end
