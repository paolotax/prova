class ClientiController < ApplicationController
  include FilterScoped
  include HasVista

  FILTER_PARAMS = [:sorted_by, :fornitori, comuni: [], tipi: [], terms: []].freeze

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  before_action :authenticate_user!
  before_action :set_cliente, only: %i[ show edit update destroy ]

  def index
    if request.format.json?
      @clienti = paginate_json(@filter.clienti)
    else
      @vista = resolve_vista
      @clienti = @filter.clienti.includes(:saldo)
      @total_count = @clienti.count

      if @vista == "tabella"
        @columns = resolve_colonne(Cliente::Columns)
        @sort = resolve_sort(@columns)
        @clienti = apply_sort(Cliente::Columns.apply_scopes(@clienti, @columns), @sort)
      end

      set_page_and_extract_portion_from @clienti
    end

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json
      format.xlsx { @clienti = @filter.clienti }
    end
  end

  def show
    unless request.format.json?
      @presenter = Clienti::Presenter.new(@cliente)
      @edit_mode = params[:edit].present?

      # Sconti applicabili: specifici per questo cliente + sconti per tutti i clienti
      @sconti_applicabili = Current.user.sconti
        .applicabili_a_cliente(@cliente.id)
        .includes(:categoria)
        .order(created_at: :desc)

      @sconti_unici = @sconti_applicabili.group_by(&:categoria_id).flat_map do |_categoria_id, sconti|
        sconti.min_by do |s|
          if s.scontabile_id.present?
            0
          elsif s.scontabile_type.present?
            1
          else
            2
          end
        end
      end
    end

    respond_to do |format|
      format.html
      format.turbo_stream { render :card if params[:card] }
      format.json
    end
  end

  def new
    @cliente = Current.account.clienti.create!(denominazione: "Nuovo cliente")
    redirect_to cliente_path(@cliente, edit: true)
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    respond_to do |format|
      format.html { redirect_to new_cliente_path }
      format.json do
        @cliente = Current.account.clienti.build(cliente_params)
        if @cliente.save
          render :show, status: :created, location: @cliente
        else
          render json: @cliente.errors, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @cliente.update(cliente_params)
        format.turbo_stream
        format.html { redirect_to cliente_path(@cliente), notice: "Cliente modificato." }
        format.json { render :show, status: :ok, location: @cliente }
      else
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cliente.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @cliente.destroy!

    respond_to do |format|
      format.html { redirect_to clienti_url, notice: "Cliente eliminato!" }
      format.json { head :no_content }
    end
  end

  private

    def set_cliente
      @cliente = Current.account.clienti.find(params[:id])
    end

    def cliente_params
      params.require(:cliente).permit(:codice_cliente,
              :tipo_cliente, :indirizzo_telematico, :email, :pec, :telefono,
              :id_paese, :partita_iva, :codice_fiscale, :denominazione,
              :nome, :cognome, :codice_eori,
              :nazione, :cap, :provincia, :comune, :indirizzo, :numero_civico, :beneficiario,
              :condizioni_di_pagamento, :metodo_di_pagamento, :banca, :fornitore)
    end

    def cliente_import_params
      params.require(:cliente_import).permit(:file)
    end

end
