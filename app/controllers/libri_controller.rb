class LibriController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = [:sorted_by, editori: [], categorie: [], discipline: [], classi: [], terms: []].freeze

  skip_before_action :set_user_filtering, if: -> { request.format.json? }

  before_action :authenticate_user!
  before_action :set_libro, only: %i[ show edit update destroy get_prezzo_e_sconto ]


  def situazione
    @situazione = Libro::Situazione.new(Current.account)
    respond_to do |format|
      format.xlsx
    end
  end

  def scarico_fascicoli
    @libri = Current.account.libri.scarico_fascicoli
    respond_to do |format|
      format.xlsx
    end
  end

  def index
    if request.format.json?
      @libri = paginate_json(@filter.libri.includes(:editore))
      return respond_to { |format| format.json }
    end

    # Combobox search con parametro q
    if params[:q].present?
      libri = Current.account.libri.search_all_word(params[:q]).includes(:giacenza)
      set_page_and_extract_portion_from libri
    else
      @total_count = @filter.libri.count
      set_page_and_extract_portion_from @filter.libri.includes(:giacenza)
    end

    respond_to do |format|
      format.turbo_stream
      format.html
      format.xlsx { @libri = @filter.libri.includes(:editore, :categoria) }
    end
  end

  def show
    @movimenti = Libro::Movimenti.new(@libro)
    @suggeriti_fascicoli = current_account.libri.potenziali_fascicoli_di(@libro).order(:titolo).limit(20)

    respond_to do |format|
      format.html
      format.turbo_stream { render :card if params[:card] }
      format.json
    end
  end

  def new
    @libro = Current.account.libri.create!(
      user: Current.user,
      titolo: "Nuovo libro",
      codice_isbn: "DRAFT-#{SecureRandom.hex(6)}",
      prezzo_in_cents: 0,
      categoria: Current.user.categorie.first
    )
    redirect_to edit_libro_path(@libro)
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    respond_to do |format|
      format.html { redirect_to new_libro_path }
      format.json do
        @libro = Current.account.libri.build(libro_params)
        @libro.user = Current.user
        if @libro.save
          render :show, status: :created, location: @libro
        else
          render json: @libro.errors, status: :unprocessable_entity
        end
      end
    end
  end


  def update
    if @libro.update(libro_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to libro_path(@libro), notice: "Libro modificato!" }
        format.json { render :show, status: :ok, location: @libro }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @libro.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @libro.destroy!

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Libro eliminato."
        render turbo_stream: turbo_stream.remove(@libro)
      end
      format.html { redirect_to libri_url, notice: "Libro eliminato.", status: :see_other }
      format.json { head :no_content }
    end
  rescue ActiveRecord::InvalidForeignKey
    message = "Impossibile eliminare \"#{@libro.titolo}\": è ancora referenziato da ordini, vendite o altri documenti."
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream_flash(alert: message) }
      format.html { redirect_to libro_url(@libro), alert: message, status: :see_other }
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def get_prezzo_e_sconto
    cliente = nil
    scuola = nil

    if params[:cliente_id].present?
      cliente = current_user.clienti.find_by(id: params[:cliente_id])
    elsif params[:scuola_id].present?
      scuola = current_account.scuole.find_by(id: params[:scuola_id])
    end

    # Se il cliente è una Scuola e il libro ha un prezzo_suggerito, usa quello con sconto 0
    if scuola.present? && @libro.prezzo_suggerito_cents.present? && @libro.prezzo_suggerito_cents > 0
      render json: {
        prezzo_copertina_cents: @libro.prezzo_suggerito_cents,
        prezzo_suggerito_cents: @libro.prezzo_suggerito_cents,
        sconto: 0.0,
        codice_isbn: @libro.codice_isbn,
        titolo: @libro.titolo
      }
    else
      sconto = Sconto.sconto_per_libro(libro: @libro, cliente: cliente, scuola: scuola, user: current_user)

      render json: {
        prezzo_copertina_cents: @libro.prezzo_in_cents,
        prezzo_suggerito_cents: @libro.prezzo_suggerito_cents,
        sconto: sconto,
        codice_isbn: @libro.codice_isbn,
        titolo: @libro.titolo
      }
    end
  end

  private

    def set_libro
      @libro = Current.account.libri.friendly.find(params[:id])
    end

    def libro_params
      params.require(:libro).permit(:user_id, :editore_id, :categoria_id, :titolo, :codice_isbn, :cm, :prezzo_in_cents, :prezzo, :prezzo_suggerito, :classe, :disciplina, :note, :categoria, :autore, :anno, :copertina)
    end
end
