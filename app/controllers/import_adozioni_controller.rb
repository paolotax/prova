class ImportAdozioniController < ApplicationController
  
  before_action :set_import_adozione, only: %i[ show edit update destroy ]

  # GET /import_adozioni or /import_adozioni.json
  def index

    @import_adozioni = ImportAdozione.elementari.di_reggio
    
    @import_adozioni = @import_adozioni.da_acquistare if params[:da_acquistare] == "si"


    if params[:search].present?      
 
      if params[:search_query] == "all"
        @import_adozioni = @import_adozioni.search_all_word(params[:search])
      else
        @import_adozioni = @import_adozioni.search_any_word(params[:search])
      end

      if params[:raggruppa_per].present?
        #@import_adozioni = @import_adozioni.raggruppa_per(params[:raggruppa_per])
        @grouped = @import_adozioni.group_by { |g| [g.CODICESCUOLA, g.CODICEISBN, g.ANNOCORSO, g.COMBINAZIONE] }
      end
      
    end
    
    #@import_adozioni =  @import_adozioni.limit(200)


    @import_adozioni = @import_adozioni.per_scuola_classe_sezione_disciplina

    @conteggio_adozioni = @import_adozioni.count;
    @conteggio_scuole   = @import_adozioni.pluck(:CODICESCUOLA).uniq.count;
    @conteggio_titoli   = @import_adozioni.pluck(:CODICEISBN).uniq.count;
    @conteggio_editori  = @import_adozioni.pluck(:EDITORE).uniq.count;


    @pagy, @import_adozioni =  pagy(@import_adozioni.all, items: 20, link_extra: 'data-turbo-action="advance"')
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
