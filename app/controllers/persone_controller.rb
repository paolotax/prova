class PersoneController < ApplicationController
  include FilterScoped
  include HasVista

  before_action :set_persona, except: [:index, :create]

  FILTER_PARAMS = [:sorted_by, :stato_contatto, terms: [], classi: [], materie: [], ruoli: []].freeze

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  def index
    if request.format.json?
      @persone = paginate_json(@filter.persone)
    else
      @vista = resolve_vista
      scope = @filter.persone
      @total_count = scope.count

      if @vista == "tabella"
        @columns = resolve_colonne(Persona::Columns)
        @sort = resolve_sort(@columns)
        scope = apply_sort(Persona::Columns.apply_scopes(scope, @columns), @sort)
      end

      set_page_and_extract_portion_from scope
    end

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end

  def show
    load_prev_next
    @appunti = @persona.appunti.includes(entry: [:goldness, :closure, :not_now]).order(created_at: :desc)

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end

  def create
    @persona = Current.account.persone.new(persona_params.except(:classe_ids, :materia))

    respond_to do |format|
      if @persona.save
        format.html { redirect_to persona_path(@persona), notice: "#{@persona.nome_completo} aggiunto" }
        format.json { render :show, status: :created, location: @persona }
      else
        format.html { redirect_back fallback_location: persone_path, alert: @persona.errors.full_messages.join(", ") }
        format.json { render json: @persona.errors, status: :unprocessable_entity }
      end
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
      respond_to do |format|
        format.json { render :show, status: :ok, location: @persona }
        format.turbo_stream do
          if params[:return_to] == "scuola" && @persona.scuola.present?
            render turbo_stream: turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@persona.scuola, :insegnanti),
              partial: "scuole/container/insegnanti",
              locals: { scuola: @persona.scuola.reload }
            )
          else
            render :show
          end
        end
        format.html do
          if params[:return_to] == "scuola" && @persona.scuola.present?
            redirect_to scuola_path(@persona.scuola), notice: "#{@persona.nome_completo} aggiornato"
          else
            redirect_to persona_path(@persona)
          end
        end
      end
    else
      respond_to do |format|
        format.json { render json: @persona.errors, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    nome = @persona.nome_completo
    scuola = @persona.scuola
    @persona.destroy

    respond_to do |format|
      format.json { head :no_content }
      if scuola.present?
        format.html { redirect_to scuola_path(scuola), notice: "#{nome} eliminato" }
      else
        format.html { redirect_to persone_path, notice: "#{nome} eliminato" }
      end
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
