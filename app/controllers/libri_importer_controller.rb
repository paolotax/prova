class LibriImporterController < ApplicationController

  before_action :authenticate_user!

  def create
    @import = LibriImporter.new(libri_importer_params)
    
    
    if @import.save
      redirect_to libri_url, notice: "Libri importati!"
    else
      redirect_to libri_url, alert: "Errore nell'importazione dei libri!"
    end
  
  end

  private

  def libri_importer_params
    params.require(:libri_importer).permit(:file, :import_method)
  end
  
end