class ZoneController < ApplicationController
  before_action :find_provincia

  def index
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

  private

    def find_provincia
      @regione   = Zona.where(regione: params[:regione].presence).first
      @provincia = Zona.where(provincia: params[:provincia].presence).first
      @grado     = TipoScuola.where(grado: params[:grado].presence).first
      @tipo      = TipoScuola.where(tipo: params[:tipo].presence).first
    end
end
