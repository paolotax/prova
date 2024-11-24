class ClientiController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_cliente, only: %i[ show edit update destroy ]

  def index
    @import = ClientiImporter.new
    @clienti = current_user.clienti.order(:denominazione)
    @clienti = filter(@clienti.all)
    #set_page_and_extract_portion_from @clienti
  end

  def show
    @situazio = ClienteSituazio.new(clientable: @cliente, user: current_user).execute
    @documenti = @cliente.documenti.includes(:causale, documento_righe: [riga: :libro]).order(data_documento: :desc, numero_documento: :desc)
  end

  def new
    @cliente = current_user.clienti.new
  end

  def edit
  end

  def create
    @cliente = current_user.clienti.new(cliente_params)

    if @cliente.save
      redirect_to(cliente_path(@cliente), notice: "Cliente inserito.") # rubocop:disable Rails/I18nLocaleTexts
    else
     # raise params.inspect
      response.status = :unprocessable_entity
    end


    # result = ClienteCreator.new.create_cliente(
    #            current_user.clienti.new(cliente_params)
    # )
    # if result.created?
    #   redirect_to clienti_url, notice: "Cliente inserito."
    #   #redirect_to cliente_path(result.cliente)
    # else
    #   @cliente = result.cliente
    #   render :new, status: :unprocessable_entity
    # end
  end

  def update
    respond_to do |format|
      if @cliente.update(cliente_params)
        format.html { redirect_to clienti_url, notice: "Cliente modificato." }
        format.json { render :show, status: :ok, location: @cliente }
      else
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

  def filtra  
  end
  
  private

    def set_cliente
      @cliente = Cliente.find(params[:id])
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

    def filter_params
      {
        ragione_sociale: params["ragione_sociale"],
        partita_iva: params["partita_iva"],
        comune: params["comune"],
        search: params["search"]
      }
    end
end
