class DocumentiController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:anno, :consegnati, :pagati, terms: [], causali: [], statuses: [], tipi_pagamento: []].freeze

  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show edit update destroy edit_status ]

  def index
    @causali = Causale.all
    @import = DocumentiImporter.new

    @tutti_documenti = @filter.documenti
    set_page_and_extract_portion_from @filter.documenti

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx
    end
  end

  def vendite
    @causali = Causale.all
    @import = DocumentiImporter.new

    # Filtra per scuola specifica se viene chiamato con import_scuola_id
    if params[:import_scuola_id].present?
      @import_scuola = ImportScuola.find(params[:import_scuola_id])
      @foglio_scuola = Scuole::FoglioScuola.new(scuola: @import_scuola)
      @documenti = @foglio_scuola.documenti
    else
      @documenti = @filter.documenti
    end

    respond_to do |format|
      format.html do
        if params[:import_scuola_id].present?
          render partial: "import_scuole/vendite", layout: false
        else
          render :index
        end
      end
      format.turbo_stream
      format.xlsx
    end
  end

  def show
    respond_to do |format|
      format.html
      format.xlsx
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
    numero_documento = (Current.account.documenti
                        .where(causale: causale)
                        .where('EXTRACT(YEAR FROM data_documento) = ?', Date.today.year)
                        .maximum(:numero_documento) || 0).to_i + 1

    @documento = Current.account.documenti.build(numero_documento: numero_documento, data_documento: Date.today, causale: causale, clientable_id: clientable_id, clientable_type: clientable_type)
    @documento.save! validate: false
    @documento.documento_righe.build.build_riga(sconto: 0.0)

    redirect_to documento_step_path(@documento, Documento.form_steps.keys.first)
  end

  def edit
  end

  def create

    result = DocumentoCreator.new.create_documento(
                Current.account.documenti.build(documento_params)
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
        flash.now[:notice] = "Documento eliminato."
        render turbo_stream: turbo_stream.remove(@documento)
      end
      format.html { redirect_to documenti_url, notice: "Documento eliminato.", status: :see_other }
    end
  end


  def nuovo_numero_documento

    causale = Causale.find(params[:causale])

    clientable_type = causale.clientable_type&.camelize || "Cliente"


    anno_corrente = Date.current.year
    ultimo_documento = Current.account.documenti.where(causale: params[:causale]).where("EXTRACT(YEAR FROM data_documento) = ?", anno_corrente).maximum(:numero_documento)
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

  def edit_status
    @field = params[:field]
    render partial: 'edit_status_modal', locals: { documento: @documento, field: @field }
  end

  private

    def set_documento
      @documento = Current.account.documenti.find(params[:id])
    end

    def documento_params
      params.require(:documento).permit(:cliente_id, :clientable_id, :clientable_type, :referente, :note, :numero_documento, :user_id, :data_documento, :causale_id, :tipo_pagamento, :consegnato_il, :pagato_il, :status, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :tipo_documento,
        documento_righe_attributes: [:id, :posizione,
          { riga_attributes: [ :id, :libro_id, :quantita, :prezzo, :prezzo_cents, :prezzo_copertina_cents, :sconto, :iva_cents, :status, :_destroy] }
        ])
    end

end
