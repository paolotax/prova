class ImportAdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_import_adozione, only: %i[ show ]

  def index

    @import_adozioni = current_user.import_adozioni.includes(:import_scuola)

    if params[:q].present?
      @import_adozioni = @import_adozioni.search_combobox params[:q]    

    else

      @import_adozioni = @import_adozioni.da_acquistare if params[:da_acquistare] == "si"
      
      @miei_editori = current_user.editori.collect{|e| e.editore}
      @import_adozioni = @import_adozioni.mie_adozioni(@miei_editori) if params[:mie_adozioni] == "si"
      
      if params[:search].present?        
        if params[:search_query] == "all"
          @import_adozioni = @import_adozioni.search_all_word(params[:search])
        else
          @import_adozioni = @import_adozioni.search_any_word(params[:search])
        end
      end
      
      @import_adozioni = @import_adozioni.where(ANNOCORSO: params[:classe]) if params[:classe].present?
      @import_adozioni = @import_adozioni.where(DISCIPLINA: params[:disciplina]) if params[:disciplina].present?
      @import_adozioni = @import_adozioni.where(EDITORE: params[:editore]) if params[:editore].present?
      @import_adozioni = @import_adozioni.where(CODICEISBN: params[:codice_isbn]) if params[:codice_isbn].present?
      
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
  
  private

    def set_import_adozione
      @import_adozione = ImportAdozione.find(params[:id])
    end

end
