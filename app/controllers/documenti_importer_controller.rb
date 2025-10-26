class DocumentiImporterController < ApplicationController
 
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!

  def new
    @import = DocumentiImporter.new
  end

  def create
    @import = DocumentiImporter.new(documenti_importer_params)
    @import.save

    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    # Limita il numero di errori per evitare cookie overflow (max 4KB)
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      documento_id: @import.documento&.id,
      errors: @import.errors.full_messages.first(10),
      has_more_errors: @import.errors.full_messages.size > 10,
      success: @import.errors.none?
    }

    redirect_to documenti_importer_path(id: 'result')
  end

  def show
    result = session[:import_result]

    unless result
      redirect_to new_documenti_importer_path, alert: "Nessun risultato di importazione disponibile"
      return
    end

    documento = result['documento_id'] ? Documento.find_by(id: result['documento_id']) : nil

    @import = OpenStruct.new(
      imported_count: result['imported_count'],
      updated_count: result['updated_count'],
      errors_count: result['errors_count'],
      documento: documento,
      errors: ActiveModel::Errors.new(self).tap { |e|
        result['errors']&.each { |msg| e.add(:base, msg) }
        if result['has_more_errors']
          e.add(:base, "... e altri errori non mostrati")
        end
      }
    )

    # Pulisci la session dopo aver letto i dati
    session.delete(:import_result)
  end



  private

  def documenti_importer_params
    params.require(:documenti_importer).permit(:file, :import_method, :documento_id, :documento)
  end
  
end