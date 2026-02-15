module Scuole
  class PersoneController < ApplicationController
    before_action :set_scuola
    before_action :set_persona

    def show
      load_classi_and_adozioni
      load_prev_next
      @appunti = @persona.appunti.includes(:entry).order(created_at: :desc)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def edit
      respond_to do |format|
        format.html { redirect_to scuola_persona_path(@scuola, @persona) }
        format.turbo_stream
      end
    end

    def update
      sync_classi if params[:persona][:classe_ids].present?

      if @persona.update(persona_params.except(:classe_ids))
        redirect_to scuola_persona_path(@scuola, @persona)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end

    def set_persona
      @persona = @scuola.persone.find(params[:id])
    end

    def persona_params
      permitted = params.require(:persona).permit(:nome, :cognome, :cellulare, :email, :telefono, :note, :classe_ids)
      if permitted[:classe_ids].is_a?(String)
        permitted[:classe_ids] = permitted[:classe_ids].split(",").reject(&:blank?)
      end
      permitted
    end

    def sync_classi
      new_ids = params[:persona][:classe_ids].to_s.split(",").reject(&:blank?)
      current_ids = @persona.classe_ids.map(&:to_s)
      cattedra = @persona.persona_classi.where.not(materia: nil).pick(:materia)

      # Remove unlinked
      (current_ids - new_ids).each do |id|
        @persona.persona_classi.find_by(classe_id: id)&.destroy
      end

      # Add new with materia
      (new_ids - current_ids).each do |id|
        @persona.persona_classi.create(classe_id: id, materia: cattedra)
      end
    end

    def load_prev_next
      all_ids = @scuola.persone.docente
                       .order(Arel.sql("posizione IS NULL, posizione, cognome, nome"))
                       .pluck(:id)
      idx = all_ids.index(@persona.id)
      @prev_persona_id = idx && idx > 0 ? all_ids[idx - 1] : nil
      @next_persona_id = idx && idx < all_ids.size - 1 ? all_ids[idx + 1] : nil
    end

    def load_classi_and_adozioni
      tipo_scuola = @scuola.classi.pick(:tipo_scuola) || "MM"
      cattedra = @persona.persona_classi.where.not(materia: nil).pick(:materia)
      discipline_miur = CattedraDisciplina.where(
        account: current_account, tipo_scuola: tipo_scuola, cattedra: cattedra
      ).pluck(:disciplina)

      @persona_classi = @persona.persona_classi.includes(:classe).order("classi.anno_corso, classi.sezione")
      @classi = @persona_classi.map(&:classe)

      adozioni = if discipline_miur.any?
        Adozione.where(classe: @classi, disciplina: discipline_miur, da_acquistare: true)
                .includes(:libro, :classe)
                .order(:disciplina, :titolo)
      else
        Adozione.none
      end

      # { disciplina => [ { adozione:, classi: [classe, ...] }, ... ] }
      @adozioni_per_disciplina = adozioni
        .group_by(&:disciplina)
        .transform_values do |ads|
          ads.group_by { |a| [a.titolo, a.editore] }
             .map do |(titolo, editore), group|
               { adozione: group.first, classi: group.map(&:classe).sort_by { |c| [c.anno_corso, c.sezione] } }
             end
        end
    end
  end
end
