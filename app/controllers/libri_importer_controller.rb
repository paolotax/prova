class LibriImporterController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!


  def new
    
  end
  def create
    @import = LibriImporter.new(libri_importer_params)    
    respond_to do |format|
      if @import.save
        format.turbo_stream do 
          flash[:notice] =  @import.flash_message
          render turbo_stream: turbo_stream.action(:redirect, libri_url)
        end
        format.html { redirect_to libri_url, notice: @import.flash_message }
      else
        format.turbo_stream do 
          flash[:alert] =  "Errore nell'importazione dei libri!"
          render turbo_stream: turbo_stream.action(:redirect, libri_url) 
        end
      end
    end
  end

  def import_ministeriali
    @import = LibriImporter.new(file: "_sql/sql_import_ministeriali.sql")
    
    respond_to do |format|
      if @import.import_ministeriali!
        format.turbo_stream do 
          flash[:notice] =  @import.flash_message
          render turbo_stream: turbo_stream.action(:redirect, libri_url)
        end
        format.html { redirect_to libri_url, notice: @import.flash_message }
      else
        format.turbo_stream do 
          flash[:alert] =  "Errore nell'importazione dei libri!"
          render turbo_stream: turbo_stream.action(:redirect, libri_url) 
        end
      end
    end
  end

  def import_csv_giunti
    
  end

  private

  def libri_importer_params
    params.require(:libri_importer).permit(:file, :import_method)
  end
  
end