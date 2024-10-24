class ImportScuoleController < ApplicationController
  
  include FilterableController

  before_action :authenticate_user!
  before_action :set_import_scuola, only: %i[ show classi_che_adottano combobox_classi ]

  def index

    @import_scuole = current_user.import_scuole.includes(:import_adozioni, :appunti)

    @import_scuole = filter(@import_scuole.all)

    @import_scuole = @import_scuole
      .joins_direzione
      .order("direz.\"DESCRIZIONECOMUNE\", direz.\"DENOMINAZIONESCUOLA\", import_scuole.\"DENOMINAZIONESCUOLA\"")
    
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
   
    @documenti = @import_scuola.documenti

    @righe = @import_scuola.righe

    @ssk = @import_scuola.appunti.ssk.dell_utente(current_user)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = FoglioScuolaPdf.new(scuola: @import_scuola, tappe: @mie_tappe.order(:data_tappa), adozioni: @import_scuola.mie_adozioni.order(:ANNOCORSO, :CODICEISBN, :SEZIONEANNO), view: view_context)
        send_data pdf.render, filename: "foglio_scuola_#{Date.today}.pdf",
                              type: "application/pdf",
                              disposition: "inline"
        
        
      end
    end
  end

  def filtra 
  end

  private

    def filter_params
      { 
        search: params["search"],
        nome: params["nome"],
        codice: params["codice"],
        direzione: params["direzione"],
        codice_direzione: params["codice_direzione"],
        comune: params["comune"],
        # codice_scuola: params["codice_scuola"],
        # comune: params["comune"],
        # scuola: params["scuola"],
        # mie_adozioni: params["mie_adozioni"],
        # da_acquistare: params["da_acquistare"],
        # nel_baule: params["nel_baule"]
      }
    end

    def set_import_scuola
      @import_scuola = ImportScuola.find(params[:id])
    end

    def import_scuola_params
      params.fetch(:import_scuola, {})
    end
end
