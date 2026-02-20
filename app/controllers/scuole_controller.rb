# Controller per le scuole tenant-specific
# Scoped attraverso Current.account
class ScuoleController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:sorted_by, :appunti_filter, :adozioni_filter, comuni: [], tipi_scuola: [], terms: []].freeze

  before_action :set_scuola, only: [:show, :edit, :update, :destroy]

  def index
    @total_count = @filter.scuole.count
    @per_direzione = @filter.sorted_by.per_direzione?

    if @per_direzione
      @scuole = @filter.scuole.includes(:direzione, :plessi)
      @gruppi_direzione = build_gruppi_direzione(@scuole)
    else
      set_page_and_extract_portion_from @filter.scuole
    end

    respond_to do |format|
      format.html
      format.xlsx { render xlsx: "index", filename: "scuole_#{Date.current}.xlsx" }
    end
  end

  def show
    @classi = @scuola.classi.includes(:adozioni).order(:anno_corso, :sezione)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @scuola = Current.account.scuole.build
  end

  def create
    @scuola = Current.account.scuole.build(scuola_params)

    if @scuola.save
      redirect_to scuola_path(@scuola), notice: "Scuola creata con successo"
    else
      render :new, status: :unprocessable_entity
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
      end
    else
      render :edit, status: :unprocessable_entity
    end
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

  def scuola_params
    params.require(:scuola).permit(
      :denominazione, :codice_ministeriale, :indirizzo, :cap,
      :comune, :provincia, :regione, :tipo_scuola,
      :email, :pec, :telefono, :note, :stato, :priorita
    )
  end
end
