class DocumentiImporterController < ApplicationController
 
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!

  def create
    @import = DocumentiImporter.new(documenti_importer_params)
    #raise @import.inspect
    respond_to do |format|
      if @import.save
        format.turbo_stream do 
          flash[:notice] =  @import.flash_message
          render turbo_stream: turbo_stream.action(:redirect, documento_url(@import.documento))
        end
        format.html do 
          redirect_to documenti_url, notice: @import.flash_message 
        end
      else
        format.turbo_stream do 
          flash[:alert] =  @import.flash_message
          render turbo_stream: turbo_stream.action(:redirect, documenti_url) 
        end
      end
    end
  end



  private

  def documenti_importer_params
    params.require(:documenti_importer).permit(:file, :import_method, :documento_id, :documento)
  end
  
end