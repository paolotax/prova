class ClientiController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_cliente, only: %i[ show edit update destroy ]

  def index
    @import = ClientiImporter.new
    @clienti = filter(current_user.clienti.all)
    
    #@clienti = @clienti.left_search(params[:search]) if params[:search].present?
    #@clienti = @clienti.filter_by(cliente: "GI")
    
    @clienti = @clienti.filter_by(
      search: params[:search],
      cliente: params[:search]
    )
    #set_page_and_extract_portion_from @clienti
  end

  def show
  end

  def new
    @cliente = current_user.clienti.new
  end

  def edit
  end

  def create
    result = ClienteCreator.new.create_cliente(
               current_user.clienti.new(cliente_params)
    )
    
    if result.created?
      redirect_to clienti_url, notice: "Cliente inserito."
      #redirect_to cliente_path(result.cliente)
    else
      @cliente = result.cliente
      render :new, status: :unprocessable_entity
    end
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

  def import
    @import = Cliente::Import.new cliente_import_params
    if @import.save
      redirect_to clienti_url, notice: "#{@import.imported_count} clienti importati."
    else
      @clienti = Cliente.all
      flash.now[:error] = @import.errors.full_messages.to_sentence
      render :index
    end
  end

  private

    def set_cliente
      @cliente = Cliente.find(params[:id])
    end

    def cliente_params
      params.require(:cliente).permit(:user, :file, :codice_cliente, :tipo_cliente, :indirizzo_telematico, :email, :pec, :telefono, :id_paese, :partita_iva, :codice_fiscale, :denominazione, :nome, :cognome, :codice_eori, :nazione, :cap, :provincia, :comune, :indirizzo, :numero_civico, :beneficiario, :condizioni_di_pagamento, :metodo_di_pagamento, :banca)
    end

    def cliente_import_params
      params.require(:cliente_import).permit(:file)
    end

    def filter_params
      {
        cliente: params["cliente"],
        comune: params["comune"],
        search: params["search"]
      }
    end
end
