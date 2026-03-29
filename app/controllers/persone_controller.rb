class PersoneController < ApplicationController
  include FilterScoped

  before_action :set_persona, except: [:index, :create]

  FILTER_PARAMS = [:sorted_by, :stato_contatto, terms: [], classi: [], materie: [], ruoli: []].freeze

  def index
    @total_count = @filter.persone.count
    set_page_and_extract_portion_from @filter.persone
  end

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
    @persona = Current.account.persone.new(
      cognome: p[:cognome],
      nome: p[:nome],
      ruolo: p[:ruolo].presence || :docente,
      email: p[:email],
      cellulare: p[:cellulare],
      scuola_id: p[:scuola_id]
    )

    if @persona.save
      redirect_to persona_path(@persona), notice: "#{@persona.nome_completo} aggiunto"
    else
      redirect_back fallback_location: persone_path, alert: @persona.errors.full_messages.join(", ")
    end
  end

  def edit
    respond_to do |format|
      format.html { redirect_to persona_path(@persona) }
      format.turbo_stream
    end
  end

  def update
    sync_classi if params[:classe_ids].present? || params.dig(:persona, :classe_ids).present?
    materia_val = params.dig(:persona, :materia) || params[:materia]
    update_materia(materia_val) if materia_val.present?

    if @persona.update(persona_params.except(:classe_ids, :materia))
      if params[:return_to] == "scuola" && @persona.scuola.present?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@persona.scuola, :insegnanti),
              partial: "scuole/container/insegnanti",
              locals: { scuola: @persona.scuola.reload }
            )
          end
          format.html { redirect_to scuola_path(@persona.scuola), notice: "#{@persona.nome_completo} aggiornato" }
        end
        return
      end

      redirect_to persona_path(@persona)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    nome = @persona.nome_completo
    scuola = @persona.scuola
    @persona.destroy

    if scuola.present?
      redirect_to scuola_path(scuola), notice: "#{nome} eliminato"
    else
      redirect_to persone_path, notice: "#{nome} eliminato"
    end
  end

  private

  def set_persona
    @persona = Current.account.persone.find(params[:id])
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

    (current_ids - new_ids).each do |id|
      @persona.persona_classi.find_by(classe_id: id)&.destroy
    end

    (new_ids - current_ids).each do |id|
      @persona.persona_classi.create(classe_id: id, materia: cattedra)
    end
  end

  def load_prev_next
    @scuola_scope = Current.account.scuole.find_by(id: params[:scuola_id]) if params[:scuola_id].present?
    scope = @scuola_scope ? @scuola_scope.persone.order(:cognome, :nome) : Current.account.persone.order(:cognome, :nome)
    all_ids = scope.pluck(:id)
    idx = all_ids.index(@persona.id)
    @prev_persona_id = idx && idx > 0 ? all_ids[idx - 1] : nil
    @next_persona_id = idx && idx < all_ids.size - 1 ? all_ids[idx + 1] : nil
  end
end
