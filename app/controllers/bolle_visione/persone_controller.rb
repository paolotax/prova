module BolleVisione
  class PersoneController < ApplicationController
    before_action :authenticate_user!
    before_action :set_bolla_visione

    def create
      @persona = @bolla_visione.scuola.persone.new(persona_params)
      @persona.account = Current.account
      @persona.ruolo = :docente if @persona.ruolo.blank?

      if @persona.save
        if @persona.referente?
          @bolla_visione.update!(referente: @persona)
        end

        materia = params.dig(:persona, :materia) || params[:materia]
        if materia.present?
          @bolla_visione.scuola.classi.each do |classe|
            @persona.persona_classi.create(classe: classe, materia: materia)
          end
        end

        redirect_to bolla_visione_path(@bolla_visione)
      else
        redirect_to bolla_visione_path(@bolla_visione), alert: @persona.errors.full_messages.join(", ")
      end
    end

    private

    def set_bolla_visione
      @bolla_visione = Current.account.bolle_visione.find(params[:bolla_visione_id])
    end

    def persona_params
      if params.key?(:persona)
        params.require(:persona).permit(:cognome, :nome, :ruolo, :email, :cellulare, :telefono)
      else
        params.permit(:cognome, :nome, :ruolo, :email, :cellulare, :telefono)
      end
    end
  end
end
