class ClientiImporterController < ApplicationController

  before_action :authenticate_user!

  def create
    @import = ClientiImporter.new(clienti_importer_params)    
    respond_to do |format|
      if @import.save
        format.turbo_stream do 
          flash[:notice] =  @import.flash_message
          render turbo_stream: turbo_stream.action(:redirect, clienti_url)
        end
        format.html { redirect_to clienti_url, notice: @import.flash_message }
      else
        format.turbo_stream do 
          flash[:alert] =  "Errore nell'importazione dei clienti"
          render turbo_stream: turbo_stream.action(:redirect, clienti_url) 
        end
      end
    end
  end

  private

  def clienti_importer_params
    params.require(:clienti_importer).permit(:file, :import_method)
  end
  
end