class DocumentoRigheController < ApplicationController
  
  before_action :authenticate_user!
  
  def new
    @documento_riga = DocumentoRiga.build(documento_id: params[:documento_id], posizione: 3)
    @documento_riga.build_riga

    render turbo_stream: turbo_stream.append(:documento_righe, partial: "documento_righe/documento_riga", locals: { documento_riga: @documento_riga})
  end

  def destroy
    @documento_riga.destroy
    respond_to do |format|
      format.html { redirect_to documento_righe_url, notice: "Documento riga was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions
end