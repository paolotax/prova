module Scuole
  class PersoneController < ApplicationController
    before_action :set_scuola
    before_action :set_persona, except: [:create]

    def show
      load_prev_next
      @appunti = @persona.appunti.includes(entry: [:goldness, :closure, :not_now]).order(created_at: :desc)

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    def create
      @persona = @scuola.persone.new(
        cognome: params[:cognome],
        nome: params[:nome],
        ruolo: :docente,
        account: Current.account
      )

      if @persona.save
        if params[:materia].present?
          @scuola.classi.each do |classe|
            @persona.persona_classi.create(classe: classe, materia: params[:materia])
          end
        end

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to scuola_path(@scuola), notice: "#{@persona.nome_completo} aggiunto" }
        end
      else
        redirect_to scuola_path(@scuola), alert: @persona.errors.full_messages.join(", ")
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

  end
end
