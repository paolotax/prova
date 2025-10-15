class ClientiImporterController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!

  def new
    @import = ClientiImporter.new
  end

  def create
    @import = ClientiImporter.new(clienti_importer_params)
    @import.save
    
    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages,
      success: @import.errors.none?
    }
    
    redirect_to clienti_importer_path(id: 'result')
  end

  def show
    result = session[:import_result]
    
    unless result
      redirect_to new_clienti_importer_path, alert: "Nessun risultato di importazione disponibile"
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

  def clienti_importer_params
    params.require(:clienti_importer).permit(:file, :import_method)
  end
  
end