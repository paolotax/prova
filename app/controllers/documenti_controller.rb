class DocumentiController < ApplicationController

  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show edit update destroy ]

  def index
    @documenti = current_user.documenti.order(data_documento: :desc, numero_documento: :desc)
    @documenti = @documenti.where(status: params[:status]) if params[:status].present?
    @documenti = @documenti.where(causale: Causale.find_by(causale: params[:causale])) if params[:causale].present?
    @documenti = @documenti.search(params[:search]) if params[:search].present?
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        #@adozioni = Array(@adozione)
        pdf = DocumentoPdf.new(@documento, view_context)
        send_data pdf.render, filename: "documento_#{@documento.id}.pdf",
                              type: "application/pdf",
                              disposition: "inline"      
      end
    end
  end
  
  def new
    #causale = Causale.find_by(causale: "Ordine Cliente")
    @documento = current_user.documenti.build(data_documento: Date.today, causale: nil)
    @documento.documento_righe.build.build_riga(sconto: 16.0)
  end

  def edit
  end

  def create

    result = DocumentoCreator.new.create_documento(
                current_user.documenti.build(documento_params)
    )

    if result.created?
      redirect_to documenti_url, notice: "Documento inserito."
    else
      @documento = result.documento
      render :new, status: :unprocessable_entity
    end
  end

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

  def destroy
    @documento.destroy!
  
    respond_to do |format|
      format.turbo_stream do 
        flash.now[:alert] = "Documento eliminato."
        render turbo_stream: turbo_stream.remove(@documento)
      end 
      format.html { redirect_to documenti_url, notice: "Documento was successfully destroyed." }
    end
  
    flash[:alert] = "Documento eliminato."
  end


  def nuovo_numero_documento
    
    causale = Causale.find(params[:causale]).causale
    if causale == "Ordine Cliente"
      clientable_type = "Cliente"
    elsif causale == "Ordine Scuola"
      clientable_type = "ImportScuola"
    else
      clientable_type = nil
    end
    
    numero_documento = current_user.documenti.where(causale: params[:causale]).maximum(:numero_documento).to_i + 1
    render json: { numero_documento: numero_documento, clientable_type: clientable_type }
  
  end


  private

    def set_documento
      @documento = Documento.find(params[:id])
    end

    def documento_params
      params.require(:documento).permit(:cliente_id, :clientable_id, :clientable_type, :numero_documento, :user_id, :data_documento, :causale_id, :tipo_pagamento, :consegnato_il, :pagato_il, :status, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :tipo_documento, 
        documento_righe_attributes: [:id, :posizione, 
          { riga_attributes: [ :id, :libro_id, :quantita, :prezzo, :prezzo_cents, :prezzo_copertina_cents, :sconto, :iva_cents, :status, :_destroy] }
        ])
    end
end
