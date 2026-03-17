module Scuole
  class PersoneController < ApplicationController
    before_action :set_scuola

    def show
      redirect_to persona_path(params[:id])
    end

    def create
      p = params[:persona] || params
      @persona = @scuola.persone.new(
        cognome: p[:cognome],
        nome: p[:nome],
        ruolo: p[:ruolo].presence || :docente,
        email: p[:email],
        cellulare: p[:cellulare],
        account: Current.account
      )

      if @persona.save
        classe_ids = params[:classe_ids].to_s.split(",").reject(&:blank?)
        target_classi = classe_ids.any? ? @scuola.classi.where(id: classe_ids) : @scuola.classi
        materia = (p[:materia] || params[:materia]).presence

        target_classi.each do |classe|
          @persona.persona_classi.create(classe: classe, materia: materia)
        end

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to scuola_path(@scuola), notice: "#{@persona.nome_completo} aggiunto" }
        end
      else
        redirect_to scuola_path(@scuola), alert: @persona.errors.full_messages.join(", ")
      end
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end
  end
end
