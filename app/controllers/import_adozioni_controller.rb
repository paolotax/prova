class ImportAdozioniController < ApplicationController
  
  before_action :set_import_adozione, only: %i[ show edit update destroy ]

  # GET /import_adozioni or /import_adozioni.json
  def index
    if params[:search].present?
      
      @import_adozioni = ImportAdozione.elementari.di_reggio.da_acquistare
      
      if params[:search_query] == "all"
        @import_adozioni = @import_adozioni.search_all_word(params[:search]).per_scuola_classe_disciplina_sezione
      else
        @import_adozioni = @import_adozioni.search_any_word(params[:search]).per_scuola_classe_disciplina_sezione
      end

      @grouped = @import_adozioni.group_by { |g| [g.CODICESCUOLA, g.CODICEISBN, g.ANNOCORSO, g.COMBINAZIONE] }
      
    else
      @import_adozioni = ImportAdozione.elementari.di_reggio.per_scuola_classe_sezione_disciplina.limit(100)
    end

    @conteggio_adozioni = @import_adozioni.count;
    @conteggio_scuole   = @import_adozioni.pluck(:CODICESCUOLA).uniq.count;
    @conteggio_titoli   = @import_adozioni.pluck(:CODICEISBN).uniq.count;
    @conteggio_editori  = @import_adozioni.pluck(:EDITORE).uniq.count;
  end

  # GET /import_adozioni/1 or /import_adozioni/1.json
  def show
  end

  # GET /import_adozioni/new
  def new
    @import_adozione = ImportAdozione.new
  end

  # GET /import_adozioni/1/edit
  def edit
  end

  # POST /import_adozioni or /import_adozioni.json
  def create
    @import_adozione = ImportAdozione.new(import_adozione_params)

    respond_to do |format|
      if @import_adozione.save
        format.html { redirect_to import_adozione_url(@import_adozione), notice: "Import adozione was successfully created." }
        format.json { render :show, status: :created, location: @import_adozione }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @import_adozione.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /import_adozioni/1 or /import_adozioni/1.json
  def update
    respond_to do |format|
      if @import_adozione.update(import_adozione_params)
        format.html { redirect_to import_adozione_url(@import_adozione), notice: "Import adozione was successfully updated." }
        format.json { render :show, status: :ok, location: @import_adozione }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @import_adozione.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /import_adozioni/1 or /import_adozioni/1.json
  def destroy
    @import_adozione.destroy!

    respond_to do |format|
      format.html { redirect_to import_adozioni_url, notice: "Import adozione was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_import_adozione
      @import_adozione = ImportAdozione.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def import_adozione_params
      params.require(:import_adozione).permit(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :TIPOGRADOSCUOLA, :COMBINAZIONE, :DISCIPLINA, :CODICEISBN, :AUTORI, :TITOLO, :SOTTOTITOLO, :VOLUME, :EDITORE, :PREZZO, :NUOVAADOZ, :DAACQUIST, :CONSIGLIATO)
    end
end
