module BolleVisione
  class PersoneController < ApplicationController
    before_action :authenticate_user!
    before_action :set_bolla_visione

    def create
      @persona = @bolla_visione.scuola.persone.new(persona_params)
      @persona.account = Current.account

      if @persona.save
        if @persona.referente?
          @bolla_visione.update!(referente: @persona)
        end

        if @persona.docente? && params[:persona][:classe_ids].present?
          classe_ids = params[:persona][:classe_ids].reject(&:blank?)
          scuola_classi = @bolla_visione.scuola.classi.where(id: classe_ids)
          materia = params[:persona][:materia]
          scuola_classi.each do |classe|
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
      params.require(:persona).permit(:cognome, :nome, :ruolo, :email, :cellulare, :telefono)
    end
  end
end
