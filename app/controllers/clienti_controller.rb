class ClientiController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:sorted_by, comuni: [], tipi: [], terms: []].freeze

  before_action :authenticate_user!
  before_action :set_cliente, only: %i[ show edit update destroy ]

  def index
    @import = ClientiImporter.new
    @clienti = @filter.clienti
    @total_count = @clienti.count
    set_page_and_extract_portion_from @clienti

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx
    end
  end

  def show
    @presenter = Clienti::Presenter.new(@cliente)

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

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @cliente = Current.account.clienti.new
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @cliente = Current.account.clienti.new(cliente_params)

    if @cliente.save
      redirect_to(cliente_path(@cliente), notice: "Cliente inserito.") # rubocop:disable Rails/I18nLocaleTexts
    else
      response.status = :unprocessable_entity
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
      params.require(:cliente).permit(:user, :file, :total_steps, :current_step, :latest_step, :codice_cliente,
              :tipo_cliente, :indirizzo_telematico, :email, :pec, :telefono,
              :id_paese, :partita_iva, :codice_fiscale, :denominazione,
              :nome, :cognome, :codice_eori,
              :nazione, :cap, :provincia, :comune, :indirizzo, :numero_civico, :beneficiario,
              :condizioni_di_pagamento, :metodo_di_pagamento, :banca)
    end

    def cliente_import_params
      params.require(:cliente_import).permit(:file)
    end

end
