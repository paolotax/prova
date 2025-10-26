class SfascicolatorController < ApplicationController
  
  before_action :authenticate_user!

  def show
  end

  def generate
    #raise params.inspect
    @libro = Libro.find(params[:sfascicolator][:libro_id])
    @documento = Documento.find(params[:sfascicolator][:documento_id])
    quantita = params[:sfascicolator][:quantita].to_i
    sconto = params[:sfascicolator][:sconto].to_f

    Sfascicolator.new(libro: @libro, documento: @documento, quantita: quantita, sconto: sconto).generate!
    redirect_to request.referrer
  end

  private

  def sfascicolator_params
    params.require(:sfascicolator).permit(:libro_id, :documento_id, :quantita, :sconto)
  end

end