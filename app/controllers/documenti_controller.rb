class DocumentiController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:anno, :sorted_by, :consegnati, :pagati, :clientable_type, :stato_documento, terms: [], causali: [], statuses: [], tipi_pagamento: []].freeze

  before_action :authenticate_user!
  before_action :set_documento, only: %i[show edit update destroy]

  def index
    @tutti_documenti = @filter.documenti
    @total_count = @tutti_documenti.count
    set_page_and_extract_portion_from @tutti_documenti

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx { @tutti_documenti = @tutti_documenti.includes(:causale, :clientable, righe: { libro: [:editore, :categoria] }) }
    end
  end

  def show
    @editing = params[:editing].present?

    if @editing
      # Prepare JSON data for Stimulus controller
      @documento_json = documento_json(@documento)
      @righe_json = righe_json(@documento)
    end

    respond_to do |format|
      format.html
      format.turbo_stream unless flash.any?
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

    @documento = Current.account.documenti.build(
      user: Current.user,
      numero_documento: numero_documento,
      data_documento: Date.today,
      causale: causale,
      clientable_id: clientable_id,
      clientable_type: clientable_type
    )

    @editing = true
    @is_new = true
    @documento_json = documento_json(@documento)
    @righe_json = '[]'

    render :show
  end

  def edit
    # Redirect to show with editing mode
    redirect_to documento_path(@documento, editing: 1)
  end

  def create
    @documento = Current.account.documenti.build(documento_params)
    @documento.user = Current.user

    if @documento.save
      redirect_to documento_url(@documento), notice: "Documento creato."
    else
      @editing = true
      @is_new = true
      @documento_json = documento_json(@documento)
      @righe_json = righe_json(@documento)
      render :show, status: :unprocessable_entity
    end
  end

  def update
    respond_to do |format|
      if @documento.update(documento_params)
        format.turbo_stream
        format.html { redirect_to documento_url(@documento), notice: "Documento aggiornato." }
        format.json { render :show, status: :ok, location: @documento }
      else
        @editing = true
        @documento_json = documento_json(@documento)
        @righe_json = righe_json(@documento)
        format.turbo_stream { render :show, status: :unprocessable_entity }
        format.html { render :show, status: :unprocessable_entity }
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

  private
    def set_documento
      @documento = Current.account.documenti.find(params[:id])
    end

    def documento_params
      params.require(:documento).permit(:cliente_id, :clientable_id, :clientable_type, :clientable_value, :referente, :note, :numero_documento, :user_id, :data_documento, :causale_id, :status, :iva_cents, :totale_cents, :spese_cents, :totale_copie, :tipo_documento,
        documento_righe_attributes: [:id, :posizione, :_destroy,
          { riga_attributes: [:id, :libro_id, :quantita, :prezzo, :prezzo_cents, :prezzo_copertina_cents, :sconto, :iva_cents, :status, :_destroy] }
        ])
    end

    def documento_json(documento)
      {
        id: documento.id,
        causale_id: documento.causale_id,
        clientable_id: documento.clientable_id,
        clientable_type: documento.clientable_type,
        numero_documento: documento.numero_documento,
        data_documento: documento.data_documento,
        referente: documento.referente,
        note: documento.note
      }.to_json
    end

    def righe_json(documento)
      documento.documento_righe.includes(riga: :libro).map do |doc_riga|
        riga = doc_riga.riga
        {
          documento_riga_id: doc_riga.id,
          riga_id: riga.id,
          libro_id: riga.libro_id,
          libro: {
            id: riga.libro&.id,
            titolo: riga.libro&.titolo,
            codice_isbn: riga.libro&.codice_isbn
          },
          titolo: riga.libro&.titolo,
          codice_isbn: riga.libro&.codice_isbn,
          quantita: riga.quantita,
          prezzo_cents: riga.prezzo_cents,
          sconto: riga.sconto
        }
      end.to_json
    end
end
