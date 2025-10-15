class LibriImporterController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!
  
  def new
    @import = LibriImporter.new
  end

  def create
    @import = LibriImporter.new(libri_importer_params)
    @import.save
    
    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages,
      success: @import.errors.none?
    }
    
    redirect_to libri_importer_path(id: 'result')
  end

  def import_ministeriali
    @import = LibriImporter.new
    @import.import_ministeriali!
    
    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages,
      success: @import.errors.none?
    }
    
    redirect_to libri_importer_path(id: 'result')
  end

  def show
    result = session[:import_result]
    
    unless result
      redirect_to new_libri_importer_path, alert: "Nessun risultato di importazione disponibile"
      return
    end
    
    @import = OpenStruct.new(
      imported_count: result['imported_count'],
      updated_count: result['updated_count'],
      errors_count: result['errors_count'],
      errors: ActiveModel::Errors.new(self).tap { |e| result['errors']&.each { |msg| e.add(:base, msg) } }
    )
    
    # Pulisci la session dopo aver letto i dati
    session.delete(:import_result)
  end

  private

  def libri_importer_params
    params.require(:libri_importer).permit(:file, :import_method)
  end
  
end