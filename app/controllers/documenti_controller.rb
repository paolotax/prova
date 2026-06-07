class DocumentiController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:anno, :sorted_by, :consegnati, :pagati, :clientable_type, :stato_documento, terms: [], causali: [], statuses: [], tipi_pagamento: []].freeze

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  before_action :authenticate_user!
  before_action :set_documento, only: %i[show edit update destroy]

  def index
    if request.format.json?
      scope = @filter.documenti
      scope = scope.where(numero_documento: params[:numero_documento]) if params[:numero_documento].present?
      scope = scope.where("data_documento >= ?", params[:data_inizio]) if params[:data_inizio].present?
      scope = scope.where("data_documento <= ?", params[:data_fine])   if params[:data_fine].present?

      if params[:libro_isbn].present? || params[:libro_categoria].present? || params[:libro_id].present?
        scope = scope.joins(righe: :libro).distinct
        scope = scope.where(libri: { codice_isbn: params[:libro_isbn] })  if params[:libro_isbn].present?
        scope = scope.where(libri: { id: params[:libro_id] })             if params[:libro_id].present?
        scope = scope.joins("INNER JOIN categorie ON categorie.id = libri.categoria_id")
                     .where("categorie.nome_categoria ILIKE ?", "%#{params[:libro_categoria]}%") if params[:libro_categoria].present?
      end

      @documenti = paginate_json(scope)
      return respond_to { |format| format.json }
    end

    @vista = resolve_vista
    @tutti_documenti = @filter.documenti
    @total_count = @tutti_documenti.count
    @stato_counts = @filter.stato_counts
    set_page_and_extract_portion_from @tutti_documenti

    respond_to do |format|
      format.html
      format.turbo_stream
      format.xlsx { @tutti_documenti = @tutti_documenti.includes(:causale, :clientable, :consegna, :pagamento, entry: [:goldness, :closure, :not_now], righe: { libro: [:editore, :categoria] }) }
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
      format.json
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
    respond_to do |format|
      format.html do
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
      format.json do
        creator = Documenti::Creator.new(**json_creator_params)
        creator.create
        if creator.ok?
          @documento = creator.documento
          render :show, status: :created, location: @documento
        else
          render json: { ok: false, error: creator.error }, status: :unprocessable_entity
        end
      end
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
      format.json { head :no_content }
    end
  end

  private
    # Vista index: "tabella" (default) o "card". Scelta persistita in cookie.
    # Il cookie viene sempre riscritto col valore risolto così che il JS di
    # back-navigation possa leggerlo e chiedere la variante giusta (row/card).
    def resolve_vista
      vista =
        if %w[tabella card].include?(params[:vista])
          params[:vista]
        else
          cookies[:documenti_vista].presence_in(%w[tabella card]) || "tabella"
        end

      cookies[:documenti_vista] = { value: vista, expires: 1.year }
      vista
    end

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

    def json_creator_params
      righe = if params[:righe].is_a?(String)
                JSON.parse(params[:righe]).map(&:symbolize_keys)
              elsif params[:righe].is_a?(Array)
                params[:righe].map { |r| r.permit(:libro_id, :quantita, :sconto, :prezzo_cents, :prezzo_unitario, :titolo, :descrizione, :codice_isbn).to_h.symbolize_keys }
              else
                []
              end
      {
        clientable_value: params[:clientable_value],
        causale_nome: params[:causale],
        note: params[:note],
        data_documento: params[:data_documento],
        numero_documento: params[:numero_documento],
        ddt_numero: params[:ddt_numero],
        spese_cents: params[:spese_cents],
        righe_params: righe
      }
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
