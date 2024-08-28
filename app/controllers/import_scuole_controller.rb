class ImportScuoleController < ApplicationController
  
  before_action :authenticate_user!
  before_action :set_import_scuola, only: %i[ show classi_che_adottano combobox_classi ]

  def index

    @import_scuole = current_user.import_scuole.includes(:import_adozioni, :appunti)

    if params[:search].present?
      if params[:search_query] == "all"
        @import_scuole = @import_scuole.search_all_word(params[:search])
      else
        @import_scuole = @import_scuole.search_any_word(params[:search])
      end
    end

    @import_scuole = @import_scuole.order(:CODICEISTITUTORIFERIMENTO, :CODICESCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA)
    @import_scuole = @import_scuole.con_appunti(current_user.appunti.non_archiviati) if params[:con_appunti] == "non_archiviati"

    @conteggio_scuole   = @import_scuole.count
    @conteggio_classi   = @import_scuole.sum(&:classi_count) 
    @conteggio_adozioni = @import_scuole.sum(&:adozioni_count)
    @conteggio_marchi   = @import_scuole.map(&:marchi).flatten.uniq.size

    @pagy, @import_scuole = pagy(@import_scuole, items: 20, link_extra: 'data-turbo-action="advance"')
  end

  def search_scuole
    @scuole = current_user.import_scuole.search params[:q]
  end

  def classi_che_adottano
    @classi_che_adottano = @import_scuola.classi.classe_che_adotta 
  end

  def combobox_classi

    
    @classi = @import_scuola.classi.classe_che_adotta 
    render layout: false

  end

  def show
    @miei_editori = current_user.miei_editori
    @mie_tappe = current_user.tappe.where(tappable_id: @import_scuola.id)
    @adozioni = current_user.adozioni.joins(:scuola).where("import_scuole.id = ?", @import_scuola.id)
    @appunti_non_archiviati = @import_scuola.appunti.non_archiviati.dell_utente(current_user)
    @appunti_archiviati = @import_scuola.appunti.archiviati.dell_utente(current_user)
    @documenti = @import_scuola.documenti.where(user_id: current_user.id)
  end

  private

    def set_import_scuola
      @import_scuola = ImportScuola.find(params[:id])
    end

    def import_scuola_params
      params.fetch(:import_scuola, {})
    end
end
