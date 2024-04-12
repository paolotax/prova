class TipiScuoleController < ApplicationController

  before_action :authenticate_user!
  
  def index
    @tipi_scuole = TipoScuola.all
  end

  def update
    @tipo_scuola = TipoScuola.find(params[:id])
    if @tipo_scuola.update(tipo_scuola_params)
      redirect_to tipi_scuole_path
    else
      render :edit
    end
  end

  private

  def tipo_scuola_params
    params.require(:tipo_scuola).permit(:tipo, :grado)
  end

end
