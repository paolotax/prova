# Controller per le scuole tenant-specific
# Scoped attraverso Current.account
class ScuoleController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:sorted_by, :appunti_filter, :adozioni_filter, province: [], aree: [], comuni: [], tipi_scuola: [], terms: []].freeze

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  before_action :set_scuola, only: [:show, :edit, :update, :destroy, :email_pattern]

  def index
    if request.format.json?
      @scuole = paginate_json(@filter.scuole)
      return respond_to { |format| format.json }
    end

    @per_direzione = @filter.sorted_by.per_direzione?

    if @per_direzione
      filtered_ids = @filter.filtered_ids
      @total_count = filtered_ids.size

      # Plessi che finiranno nested sotto la loro direzione (non sono capogruppo)
      nested_plessi = Current.scuole
        .where(id: filtered_ids)
        .where.not(direzione_id: nil)
        .where(direzione_id: filtered_ids)

      nested_ids = nested_plessi.pluck(:id)
      @direzioni_count = nested_plessi.distinct.count(:direzione_id)

      # Capogruppo = direzioni + scuole isolate + plessi la cui direzione non è nei filtri
      leaders = Current.scuole
        .where(id: filtered_ids - nested_ids)
        .left_joins(:direzione)
        .order(*per_direzione_order)

      set_page_and_extract_portion_from leaders

      # Carica i dati completi solo per i gruppi della pagina corrente
      leader_ids = @page.records.map(&:id)
      plessi_ids = Current.scuole
        .where(id: filtered_ids, direzione_id: leader_ids)
        .pluck(:id)

      page_scuole = Current.scuole
        .where(id: leader_ids + plessi_ids)
        .includes(:appunti, :direzione, :plessi, memberships: :user)
        .left_joins(:direzione)
        .order(*per_direzione_order)

      @gruppi_direzione = build_gruppi_direzione(page_scuole)
    else
      @total_count = @filter.scuole.count
      set_page_and_extract_portion_from @filter.scuole
    end

    respond_to do |format|
      format.html
      format.xlsx {
        @scuole_xlsx = @filter.scuole.includes(:classi)
        render xlsx: "index", filename: "scuole_#{Date.current}.xlsx"
      }
    end
  end

  def show
    @classi = @scuola.classi.attive.includes(:adozioni).order(:anno_corso, :sezione)
    @edit_mode = params[:edit].present?

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
    end
  end

  def new
    @scuola = Current.account.scuole.create!(denominazione: "Nuova scuola")
    redirect_to scuola_path(@scuola, edit: true)
  end

  def create
    @scuola = Current.account.scuole.build(scuola_params)

    if @scuola.save
      redirect_to scuola_path(@scuola), notice: "Scuola creata con successo"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def edit
    respond_to do |format|
      format.html { redirect_to scuola_path(@scuola) }
      format.turbo_stream
    end
  end

  def update
    if @scuola.update(scuola_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to scuola_path(@scuola) }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @scuola.errors, status: :unprocessable_entity }
      end
    end
  end

  def email_pattern
    source = @scuola.email_pattern.present? ? @scuola : @scuola.direzione
    render json: {
      pattern: source&.email_pattern,
      dominio: source&.email_dominio
    }
  end

  def destroy
    @scuola.destroy
    redirect_to scuole_path, notice: "Scuola eliminata"
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:id])
  end

  # Raggruppa scuole per direzione, mantenendo l'ordine del filtro
  # (provincia, comune, denominazione direzione)
  def build_gruppi_direzione(scuole)
    scuole_by_id = scuole.index_by(&:id)
    gruppi = {}
    ordine = [] # preserva l'ordine di prima apparizione

    scuole.each do |scuola|
      if scuola.direzione_id.present? && scuole_by_id[scuola.direzione_id]
        # Plesso con direzione visibile: raggruppa sotto la direzione
        key = scuola.direzione_id
        unless gruppi[key]
          gruppi[key] = { direzione: scuole_by_id[key], plessi: [] }
          ordine << key
        end
        gruppi[key][:plessi] << scuola
      elsif scuola.direzione_id.present?
        # Plesso ma la direzione non è nei risultati: mostra come isolata
        gruppi[scuola.id] = { direzione: nil, plessi: [scuola] }
        ordine << scuola.id
      elsif scuola.plessi.any? { |p| scuole_by_id[p.id] }
        # Direzione con plessi visibili
        unless gruppi[scuola.id]
          gruppi[scuola.id] = { direzione: scuola, plessi: [] }
          ordine << scuola.id
        end
      else
        # Scuola isolata
        gruppi[scuola.id] = { direzione: nil, plessi: [scuola] }
        ordine << scuola.id
      end
    end

    ordine.map { |key| gruppi[key] }
  end

  def per_direzione_order
    [
      Arel.sql("COALESCE(direzioni_scuole.provincia, scuole.provincia)"),
      Arel.sql("COALESCE(direzioni_scuole.area, scuole.area) NULLS FIRST"),
      Arel.sql("COALESCE(direzioni_scuole.comune, scuole.comune)"),
      Arel.sql("COALESCE(direzioni_scuole.denominazione, scuole.denominazione)"),
      :tipo_scuola, :denominazione
    ]
  end

  def scuola_params
    params.require(:scuola).permit(
      :denominazione, :codice_ministeriale, :indirizzo, :cap,
      :comune, :provincia, :sigla_provincia, :regione, :tipo_scuola,
      :email, :pec, :telefono, :note, :stato, :priorita, :area,
      :email_pattern, :email_dominio, :direzione_id
    )
  end
end
