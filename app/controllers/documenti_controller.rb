class DocumentiController < ApplicationController

  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show edit update destroy ]

  # GET /documenti or /documenti.json
  def index

    # if params[:search].present?
    #   @documenti = Views::Documento.search_any_word(params[:search]).order(data_documento: :desc)
    # else
    #   @documenti = Views::Documento.order(data_documento: :desc)
    # end

    @documenti = Documento.all
  end

  # GET /documenti/1 or /documenti/1.json
  def show
  end

  # GET /documenti/new
  def new
    @documento = current_user.documenti.build(data_documento: Date.today)
  end

  # GET /documenti/1/edit
  def edit
  end

  # POST /documenti or /documenti.json
  def create
    @documento = current_user.documenti.build(documento_params)

    #raise params.inspect
    respond_to do |format|
      if @documento.save
        format.html { redirect_to documento_url(@documento), notice: "Documento was successfully created." }
        format.json { render :show, status: :created, location: @documento }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @documento.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /documenti/1 or /documenti/1.json
  def update
    respond_to do |format|
      if @documento.update(documento_params)
        format.html { redirect_to documento_url(@documento), notice: "Documento was successfully updated." }
        format.json { render :show, status: :ok, location: @documento }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @documento.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /documenti/1 or /documenti/1.json
  def destroy
    @documento.destroy!

    respond_to do |format|
      format.html { redirect_to documenti_url, notice: "Documento was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_documento
      @documento = Documento.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def documento_params
      params.require(:documento).permit(:cliente_id, :clientable_id, :clientable_type, :numero_documento, :user_id, :data_documento, :causale_id, :tipo_pagamento, :consegnato_il, :pagato_il, :status, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :tipo_documento)
    end
end
