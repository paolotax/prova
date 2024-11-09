class ImportScuoleController < ApplicationController
  
  include FilterableController

  before_action :authenticate_user!
  before_action :set_import_scuola, only: %i[ show classi_che_adottano combobox_classi ]

  def index

    @import_scuole = current_user.import_scuole
      .includes(:appunti_da_completare, :direzione)

    @import_scuole = filter(@import_scuole.all)

    @import_scuole = @import_scuole
      .joins_direzione
      .order("direz.\"DESCRIZIONECOMUNE\", direz.\"DENOMINAZIONESCUOLA\", import_scuole.\"DENOMINAZIONESCUOLA\"")
    
    @import_scuole = @import_scuole.con_appunti(current_user.appunti.non_archiviati) if params[:con_appunti] == "non_archiviati"

    @stats = Scuole::Stats.new(@import_scuole).stats

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

    @foglio_scuola = Scuole::FoglioScuola.new(scuola: @import_scuola)

    respond_to do |format|
      format.html
      format.pdf do
        pdf = FoglioScuolaPdf.new(scuola: @import_scuola, 
            tappe: @foglio_scuola.mie_tappe.order(:data_tappa), 
            adozioni: @foglio_scuola.mie_adozioni.order(:ANNOCORSO, :CODICEISBN, :SEZIONEANNO), view: view_context)
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
        con_appunti: params["con_appunti"],
     }.compact_blank!
    end

    def set_import_scuola
      @import_scuola = ImportScuola.friendly.find(params[:id])
    end

    def import_scuola_params
      params.fetch(:import_scuola, {})
    end
end
