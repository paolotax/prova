class DocumentiController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show edit update destroy ]

  def index
    @causali = Causale.all
    @import = DocumentiImporter.new
    
    @documenti = current_user.documenti
        .joins("left outer join import_scuole on clientable_type = 'ImportScuola' and clientable_id = import_scuole.id")
        .joins("left outer join clienti on clientable_type = 'Cliente' and clientable_id = clienti.id")
        .includes(:causale, :righe, documento_righe: [riga: :libro])
        .order(updated_at: :desc)

    @documenti = filter(@documenti.all)
    
    respond_to do |format|
      format.html do 
        @pagy, @documenti = pagy(@documenti.all, items: 5)
      end
      format.xlsx
    end
  end

  def show
    # @filter_params = filter_params
    # @documenti = current_user.documenti.includes(:causale, documento_righe: [:riga]).order(data_documento: :desc, numero_documento: :desc)    
    # @documenti = filter(@documenti.all)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = DocumentoPdf.new(@documento, view_context)
        send_data pdf.render, filename: "documento_#{@documento.id}.pdf",
                              type: "application/pdf",
                              disposition: "inline"      
      end
    end
  end
  
  def new
    causale = Causale.find_by(causale: params[:causale])
    clientable_id = params[:clientable_id]
    clientable_type = params[:clientable_type]
    numero_documento = (current_user.documenti
                        .where(causale: causale)
                        .where('EXTRACT(YEAR FROM data_documento) = ?', Date.today.year)
                        .maximum(:numero_documento) || 0).to_i + 1
    
    @documento = current_user.documenti.build(numero_documento: numero_documento, data_documento: Date.today, causale: causale, clientable_id: clientable_id, clientable_type: clientable_type)
    @documento.save! validate: false
    @documento.documento_righe.build.build_riga(sconto: 0.0)  
  
    redirect_to documento_step_path(@documento, Documento.form_steps.keys.first)
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
      # format.turbo_stream do 
      #   flash.now[:alert] = "Documento eliminato."
      #   render turbo_stream: turbo_stream.remove(@documento)
      # end 
      format.html { redirect_to documenti_url, alert: "Documento eliminato." }
    end
  end


  def nuovo_numero_documento
    
    causale = Causale.find(params[:causale])
    
    clientable_type = causale.clientable_type&.camelize || "Cliente"
    

    anno_corrente = Date.current.year
    ultimo_documento = current_user.documenti.where(causale: params[:causale]).where("EXTRACT(YEAR FROM data_documento) = ?", anno_corrente).maximum(:numero_documento)
    numero_documento = (ultimo_documento || 0) + 1
    render json: { numero_documento: numero_documento, clientable_type: clientable_type }
  
  end

  def filtra 
    @causali = Causale.all
  end

  def esporta_xml
    @documento = Documento.find(params[:id])
    xml_generator = FatturaElettronicaXml.new(@documento)
    
    respond_to do |format|
      format.xml do
        xml_content = xml_generator.genera_xml
        send_data xml_content, 
                  filename: "IT#{@documento.user.azienda_partita_iva}_#{@documento.numero_documento}.xml",
                  type: 'application/xml',
                  disposition: 'attachment'
      end
    end
  end

  private

    def set_documento
      @documento = current_user.documenti.find(params[:id])
    end

    def documento_params
      params.require(:documento).permit(:cliente_id, :clientable_id, :clientable_type, :referente, :note, :numero_documento, :user_id, :data_documento, :causale_id, :tipo_pagamento, :consegnato_il, :pagato_il, :status, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :tipo_documento, 
        documento_righe_attributes: [:id, :posizione, 
          { riga_attributes: [ :id, :libro_id, :quantita, :prezzo, :prezzo_cents, :prezzo_copertina_cents, :sconto, :iva_cents, :status, :_destroy] }
        ])
    end

    def filter_params 
      {
        search: params["search"],
        search_libro: params["search_libro"],
        causale: params["causale"],
        status: params["status"],
        tipo_pagamento: params["tipo_pagamento"],
        anno: params["anno"],
        ordina_per: params["ordina_per"]
      }.compact_blank
    end

end
