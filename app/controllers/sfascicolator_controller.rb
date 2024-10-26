class SfascicolatorController < ApplicationController
  
  before_action :authenticate_user!

  def show
  end

  def generate
    #raise params.inspect
    @libro = Libro.find(params[:sfascicolator][:libro_id])
    @documento = Documento.find(params[:sfascicolator][:documento_id])
    Sfascicolator.new(libro: @libro, documento: @documento).generate!
    redirect_to request.referrer
  end

  private

  def sfascicolator_params
    params.require(:sfascicolator).permit(:libro_id, :documento_id)
  end

end