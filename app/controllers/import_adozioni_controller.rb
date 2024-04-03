class ImportAdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_import_adozione, only: %i[ show edit update destroy ]

  def index

    @import_adozioni = current_user.import_adozioni.includes(:import_scuola)

    if params[:q].present?
      @import_adozioni = @import_adozioni.search_combobox params[:q]    

    else

      @import_adozioni = @import_adozioni.da_acquistare if params[:da_acquistare] == "si"
      
      @miei_editori = current_user.editori.collect{|e| e.editore}
      @import_adozioni = @import_adozioni.mie_adozioni(@miei_editori) if params[:mie_adozioni] == "si"
      @import_adozioni = @import_adozioni.where(ANNOCORSO: params[:classe]) if params[:classe].present?


      if params[:search].present?      
  
        if params[:search_query] == "all"
          @import_adozioni = @import_adozioni.search_all_word(params[:search])
        else
          @import_adozioni = @import_adozioni.search_any_word(params[:search])
        end
      end
            
      @conteggio_adozioni = @import_adozioni.count;
      @conteggio_scuole   = @import_adozioni.pluck(:CODICESCUOLA).uniq.count;
      @conteggio_titoli   = @import_adozioni.pluck(:CODICEISBN).uniq.count;
      @conteggio_editori  = @import_adozioni.pluck(:EDITORE).uniq.count;
    end

    @import_adozioni = @import_adozioni.per_scuola_classe_sezione_disciplina

    set_page_and_extract_portion_from @import_adozioni

    respond_to do |format|
      format.html
      format.xlsx
      format.turbo_stream
    end
  end

  def show
  end

  def new
    @import_adozione = ImportAdozione.new
  end

  def edit
  end

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

  def destroy
    @import_adozione.destroy!

    respond_to do |format|
      format.html { redirect_to import_adozioni_url, notice: "Import adozione was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

    def set_import_adozione
      @import_adozione = ImportAdozione.find(params[:id])
    end

    def import_adozione_params
      params.require(:import_adozione).permit(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :TIPOGRADOSCUOLA, :COMBINAZIONE, :DISCIPLINA, :CODICEISBN, :AUTORI, :TITOLO, :SOTTOTITOLO, :VOLUME, :EDITORE, :PREZZO, :NUOVAADOZ, :DAACQUIST, :CONSIGLIATO)
    end
end
