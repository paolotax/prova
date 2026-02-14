module Scuole
  class CattedreController < ApplicationController
    before_action :set_scuola

    def show
      @tipo_scuola = tipo_scuola_for(@scuola)
      @cattedre = @scuola.persone.joins(:persona_classi)
                         .order(Arel.sql("MIN(persone.posizione)"))
                         .group("persona_classi.materia")
                         .pluck("persona_classi.materia").compact
      all_discipline = @scuola.classi.joins(:adozioni)
                              .distinct.pluck("adozioni.disciplina").compact
      @mappings = CattedraDisciplina.where(account: current_account, tipo_scuola: @tipo_scuola)

      # Order discipline: mapped ones follow cattedre order, unmapped at the end
      mapped_order = @mappings.where(cattedra: @cattedre).pluck(:cattedra, :disciplina)
      ordered_mapped = @cattedre.flat_map { |c| mapped_order.select { |mc, _| mc == c }.map(&:last) }
      unmapped = (all_discipline - ordered_mapped).sort
      @discipline = (ordered_mapped & all_discipline) + unmapped
    end

    def create
      mapping = CattedraDisciplina.find_or_initialize_by(
        account: current_account,
        cattedra: params[:cattedra],
        disciplina: params[:disciplina],
        tipo_scuola: params[:tipo_scuola]
      )

      if mapping.new_record? && mapping.save
        render json: { id: mapping.id, status: "created" }
      elsif mapping.persisted?
        render json: { id: mapping.id, status: "exists" }
      else
        render json: { errors: mapping.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      mapping = CattedraDisciplina.find_by(
        account: current_account,
        cattedra: params[:cattedra],
        disciplina: params[:disciplina],
        tipo_scuola: params[:tipo_scuola]
      )

      if mapping&.destroy
        render json: { status: "deleted" }
      else
        render json: { status: "not_found" }, status: :not_found
      end
    end

    private
      def set_scuola
        @scuola = Scuola.find(params[:scuola_id])
      end

      def tipo_scuola_for(scuola)
        scuola.classi.pick(:tipo_scuola) || "MM"
      end
  end
end
