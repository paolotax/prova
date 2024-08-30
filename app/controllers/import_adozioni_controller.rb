class ImportAdozioniController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_import_adozione, only: %i[ show ]

  def index

    @import_adozioni = current_user.import_adozioni.preload(:import_scuola, :saggi, :seguiti, :kit)

    if params[:q].present?
      @import_adozioni = @import_adozioni.search_combobox params[:q]    

    else      

      @import_adozioni = @import_adozioni.mie_adozioni if params[:mie_adozioni] == "si"
      
      @import_adozioni = @import_adozioni.mie_adozioni.nel_baule_di_oggi if params[:filter] == "oggi"
      @import_adozioni = @import_adozioni.mie_adozioni.nel_baule_di_domani if params[:filter] == "domani"
      
      @import_adozioni = @import_adozioni.filtra(params)
      
      @conteggio_adozioni = @import_adozioni.count;
      @conteggio_scuole   = @import_adozioni.pluck(:CODICESCUOLA).uniq.count;
      @conteggio_titoli   = @import_adozioni.pluck(:CODICEISBN).uniq.count;
      @conteggio_editori  = @import_adozioni.pluck(:EDITORE).uniq.count;
    end

    @import_adozioni = @import_adozioni.per_scuola_classe_sezione_disciplina
    #@import_adozioni = @import_adozioni.raggruppate
    
    set_page_and_extract_portion_from @import_adozioni

    respond_to do |format|
      format.html
      format.xlsx
      format.turbo_stream
      format.pdf { print_pdf(@import_adozioni) }
    end
  end

  def show
  end

  def bulk_update
    @import_adozioni = current_user.import_adozioni
                  .where(id: params.fetch(:import_adozione_ids, []).compact)
                  .order(:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA, :CODICEISBN) 
    respond_to do |format|
      format.pdf { print_pdf(@import_adozioni) }
    end 
  end
  
  private

    def set_import_adozione
      @import_adozione = ImportAdozione.find(params[:id])
    end

    def print_pdf(import_adozioni)
      pdf = ImportAdozionePdf.new(import_adozioni, view_context)
        send_data pdf.render, filename: "sovfapacchi_#{Date.today}.pdf",
                              type: "application/pdf",
                              disposition: "inline"
    end
end
