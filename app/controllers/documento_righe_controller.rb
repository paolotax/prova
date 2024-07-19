class DocumentoRigheController < ApplicationController
  
  before_action :authenticate_user!
  
  def new
    @documento_riga = DocumentoRiga.build(documento_id: params[:documento_id])
    @documento_riga.build_riga(sconto: 16.0)

    render turbo_stream: turbo_stream.append(:documento_righe, partial: "documento_righe/documento_riga", locals: { documento_riga: @documento_riga})
  end

  def destroy
    documento_riga = DocumentoRiga.find(params[:id])
    documento_riga.destroy
  rescue ActiveRecord::RecordNotFound
    documento_riga = DocumentoRiga.new(id: params[:id])
  ensure
    render turbo_stream: turbo_stream.remove(documento_riga.id)
  end

end