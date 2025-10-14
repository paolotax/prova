class DocumentiController < ApplicationController

  include FilterableController

  before_action :authenticate_user!
  before_action :set_documento, only: %i[ show edit update destroy edit_status ]

  def index
    @causali = Causale.all
    @import = DocumentiImporter.new

    @documenti = current_user.documenti
        .solo_padri
        .joins("left outer join import_scuole on documenti.clientable_type = 'ImportScuola' and documenti.clientable_id = import_scuole.id")
        .joins("left outer join clienti on documenti.clientable_type = 'Cliente' and documenti.clientable_id = clienti.id")
        .includes(:causale, :righe, documento_righe: [riga: :libro])
        .order(data_documento: :desc, causale_id: :desc, numero_documento: :desc)

    @documenti = filter(@documenti.all)

    @tutti_documenti = @documenti.all
    @pagy, @documenti = pagy(@documenti.all, items: 20)

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx
    end
  end

  def vendite
    @causali = Causale.all
    @import = DocumentiImporter.new

    @documenti = current_user.documenti
        .joins("left outer join import_scuole on documenti.clientable_type = 'ImportScuola' and documenti.clientable_id = import_scuole.id")
        .joins("left outer join clienti on documenti.clientable_type = 'Cliente' and documenti.clientable_id = clienti.id")
        .includes(:causale, :righe, documento_righe: [riga: :libro])
        .order(data_documento: :desc, causale_id: :desc, numero_documento: :desc)

    # Filtra per scuola specifica se viene chiamato con import_scuola_id
    if params[:import_scuola_id].present?
      @import_scuola = ImportScuola.find(params[:import_scuola_id])
      @foglio_scuola = Scuole::FoglioScuola.new(scuola: @import_scuola)
      @documenti = @foglio_scuola.documenti
    end

    @documenti = filter(@documenti.all)

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

  def edit_status
    @field = params[:field]
    render partial: 'edit_status_modal', locals: { documento: @documento, field: @field }
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
        ordina_per: params["ordina_per"],
        consegnato_il: params["consegnato_il"],
        pagato_il: params["pagato_il"],
        consegnati: params["consegnati"],
        pagati: params["pagati"],
        tappe_del_giorno: params["tappe_del_giorno"],
        nel_baule_del_giorno: params["nel_baule_del_giorno"]
      }.compact_blank
    end

end
