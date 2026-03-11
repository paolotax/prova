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
        format.json do
          render json: {
            id: @persona.id,
            cognome: @persona.cognome,
            nome: @persona.nome,
            email: @persona.email,
            cellulare: @persona.cellulare,
            ruolo: @persona.ruolo,
            materia: @persona.persona_classi.where.not(materia: nil).pick(:materia),
            classe_ids: @persona.classe_ids
          }
        end
      end
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

    def edit
      respond_to do |format|
        format.html { redirect_to scuola_persona_path(@scuola, @persona) }
        format.turbo_stream
      end
    end

    def update
      sync_classi if params[:classe_ids].present? || params.dig(:persona, :classe_ids).present?
      materia_val = params.dig(:persona, :materia) || params[:materia]
      update_materia(materia_val) if materia_val.present?

      new_scuola_id = persona_params[:scuola_id]
      scuola_cambiata = new_scuola_id.present? && new_scuola_id != @scuola.id.to_s

      if @persona.update(persona_params.except(:classe_ids, :materia))
        if params[:return_to] == "scuola"
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.replace(
                ActionView::RecordIdentifier.dom_id(@scuola, :insegnanti),
                partial: "scuole/container/insegnanti",
                locals: { scuola: @scuola.reload }
              )
            end
            format.html { redirect_to scuola_path(@scuola), notice: "#{@persona.nome_completo} aggiornato" }
          end
          return
        elsif scuola_cambiata
          redirect_to scuola_persona_path(@persona.scuola, @persona)
        else
          redirect_to scuola_persona_path(@scuola, @persona)
        end
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @persona.destroy
      redirect_to scuola_path(@scuola), notice: "#{@persona.nome_completo} eliminato"
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end

    def set_persona
      @persona = @scuola.persone.find_by(id: params[:id]) ||
                 Current.account.persone.find(params[:id])
    end

    def persona_params
      permitted = params.require(:persona).permit(:nome, :cognome, :cellulare, :email, :telefono, :note, :ruolo, :scuola_id, :classe_ids, :materia)
      if permitted[:classe_ids].is_a?(String)
        permitted[:classe_ids] = permitted[:classe_ids].split(",").reject(&:blank?)
      end
      permitted
    end

    def update_materia(materia)
      @persona.persona_classi.update_all(materia: materia)
    end

    def sync_classi
      raw = params[:classe_ids] || params.dig(:persona, :classe_ids)
      new_ids = raw.to_s.split(",").reject(&:blank?)
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
      all_ids = @scuola.persone.where(ruolo: [:docente, :referente])
                       .order(Arel.sql("posizione IS NULL, posizione, cognome, nome"))
                       .pluck(:id)
      idx = all_ids.index(@persona.id)
      @prev_persona_id = idx && idx > 0 ? all_ids[idx - 1] : nil
      @next_persona_id = idx && idx < all_ids.size - 1 ? all_ids[idx + 1] : nil
    end

  end
end
