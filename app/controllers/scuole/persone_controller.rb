module Scuole
  class PersoneController < ApplicationController
    before_action :set_scuola
    before_action :set_persona

    def show
      @tipo_scuola = tipo_scuola_for(@scuola)
      cattedra = @persona.persona_classi.first&.materia
      discipline_miur = CattedraDisciplina.where(
        account: current_account, tipo_scuola: @tipo_scuola, cattedra: cattedra
      ).pluck(:disciplina)

      @persona_classi = @persona.persona_classi.includes(:classe).order("classi.anno_corso, classi.sezione")
      @classi = @persona_classi.map(&:classe)
      @adozioni_per_classe = if discipline_miur.any?
        Adozione.where(classe: @classi, disciplina: discipline_miur)
                .includes(:libro)
                .group_by(&:classe_id)
      else
        {}
      end
      @appunti = @persona.appunti.includes(:entry).order(created_at: :desc)
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end

    def set_persona
      @persona = @scuola.persone.find(params[:id])
    end

    def tipo_scuola_for(scuola)
      scuola.classi.pick(:tipo_scuola) || "MM"
    end
  end
end
