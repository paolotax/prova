class ClientiController < ApplicationController
  before_action :set_cliente, only: %i[ show edit update destroy ]

  # GET /clienti or /clienti.json
  def index
    @clienti = Cliente.all
  end

  # GET /clienti/1 or /clienti/1.json
  def show
  end

  # GET /clienti/new
  def new
    @cliente = Cliente.new
  end

  # GET /clienti/1/edit
  def edit
  end

  # POST /clienti or /clienti.json
  def create
    @cliente = Cliente.new(cliente_params)

    respond_to do |format|
      if @cliente.save
        format.html { redirect_to cliente_url(@cliente), notice: "Cliente was successfully created." }
        format.json { render :show, status: :created, location: @cliente }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @cliente.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /clienti/1 or /clienti/1.json
  def update
    respond_to do |format|
      if @cliente.update(cliente_params)
        format.html { redirect_to cliente_url(@cliente), notice: "Cliente was successfully updated." }
        format.json { render :show, status: :ok, location: @cliente }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cliente.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /clienti/1 or /clienti/1.json
  def destroy
    @cliente.destroy!

    respond_to do |format|
      format.html { redirect_to clienti_url, notice: "Cliente was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def import
    Cliente.import(params[:file])
    redirect_to clienti_url, notice: "Clienti imported."
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cliente
      @cliente = Cliente.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def cliente_params
      params.require(:cliente).permit(:file, :codice_cliente, :tipo_cliente, :indirizzo_telematico, :email, :pec, :telefono, :id_paese, :partita_iva, :codice_fiscale, :denominazione, :nome, :cognome, :codice_eori, :nazione, :cap, :provincia, :comune, :indirizzo, :numero_civico, :beneficiario, :condizioni_di_pagamento, :metodo_di_pagamento, :banca)
    end
end
