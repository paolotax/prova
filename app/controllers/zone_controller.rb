class ZoneController < ApplicationController
  
  before_action :authenticate_user!
  before_action :find_provincia

  def index
    @zone = current_user.zone
  end

  def select_zone
    # il controller Zona si riferisce all'utente non alla tabella Zone (che sono tutte le province e comuni italiani e non quelle assegnate all'utente)
    @regioni = Zona.order(:regione)
                   .select(:regione).distinct || []
    
    @province = Zona.where(regione: @regione&.regione)
                    .order(:provincia)
                    .select(:provincia).distinct || []

    @gradi = TipoScuola.order(:grado)
                       .select(:grado).distinct || []
    
    @tipi  = TipoScuola.where(grado: @grado&.grado)
                       .order(:tipo)
                       .select(:tipo).distinct || []
  end

  def assegna_scuole
    
    if !params[:hregione].blank?
      
      @regione   = params[:hregione]
      @provincia = params[:hprovincia]
      @tipo      = params[:htipo]
      @grado     = params[:hgrado]
      
      @provincia_tipo = (@provincia + "-" + @tipo).downcase.gsub(" ", "-")
      
      @scuole_da_assegnare = ImportScuola.where(REGIONE: @regione)

      if @provincia != "tutte"
        @scuole_da_assegnare = @scuole_da_assegnare.where(PROVINCIA: @provincia)
      end

      if @grado != "tutti"
        tipi = TipoScuola.where(grado: @grado).pluck(:tipo)
        @scuole_da_assegnare = @scuole_da_assegnare.where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipi)
      end
      
      if @tipo != "tutti"
        @scuole_da_assegnare = @scuole_da_assegnare.where(DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: @tipo)
      end
       
      @scuole_da_assegnare.includes(:direzione).to_a.sort_by { |s| 
        [
          s.PROVINCIA.to_s,
          (s.direzione.present? ? s.direzione.DESCRIZIONECOMUNE.to_s : s.DESCRIZIONECOMUNE.to_s).to_s,
          s.CODICEISTITUTORIFERIMENTO.to_s,
          s.CODICESCUOLA.to_s
        ]
      }.each do |s|
        current_user.import_scuole << s unless current_user.import_scuole.include?(s)
      end

    end
  end

  def rimuovi_scuole
    #fail

    @id_zona = "#{params[:provincia]}-#{params[:grado]}".gsub(" ", "-").downcase

    @scuole_da_rimuovere = ImportScuola.joins(:tipo_scuola).where(PROVINCIA: params[:provincia]).where("tipi_scuole.grado = ?", params[:grado])
    #raise @scuole_da_rimuovere.inspect
    @scuole_da_rimuovere.each {|s| current_user.import_scuole.delete(s)}

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to current_user notice: "Scuole eliminate!"  }
    end
  end

  private

    def find_provincia
      @regione   = Zona.where(regione: params[:regione].presence).first
      @provincia = Zona.where(provincia: params[:provincia].presence).first
      @grado     = TipoScuola.where(grado: params[:grado].presence).first
      @tipo      = TipoScuola.where(tipo: params[:tipo].presence).first
    end
end
