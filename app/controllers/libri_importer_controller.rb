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
    # Limita gli errori a max 20 per evitare cookie overflow
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages.first(20),
      success: @import.errors.none?
    }

    redirect_to libri_importer_path(id: 'result')
  end

  def import_ministeriali
    @import = LibriImporter.new
    @import.import_ministeriali!

    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    # Limita gli errori a max 20 per evitare cookie overflow
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages.first(20),
      success: @import.errors.none?
    }

    redirect_to libri_importer_path(id: 'result')
  end

  def import_confezioni
    @import = LibriImporter.new(libri_importer_params)
    @import.import_confezioni_excel!

    # Salva sempre i risultati (successo o errore) e mostra la pagina show
    # Limita gli errori a max 20 per evitare cookie overflow
    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      created_count: @import.created_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages.first(20),
      success: @import.errors.none?
    }

    redirect_to libri_importer_path(id: 'result')
  end

  def export_confezioni
    sql = <<-SQL
      SELECT
        confezioni.codice_isbn as confezione_isbn,
        confezioni.titolo as confezione_titolo,
        fascicoli.codice_isbn as fascicolo_isbn,
        fascicoli.titolo as fascicolo_titolo,
        COALESCE(confezione_righe.row_order, 0) as row_order
      FROM confezione_righe
        INNER JOIN libri as confezioni ON confezioni.id = confezione_righe.confezione_id
        INNER JOIN libri as fascicoli ON fascicoli.id = confezione_righe.fascicolo_id
      WHERE confezioni.user_id = #{current_user.id}
      ORDER BY confezioni.codice_isbn, COALESCE(confezione_righe.row_order, 999999)
    SQL

    @confezioni = ActiveRecord::Base.connection.execute(sql)

    respond_to do |format|
      format.xlsx
    end
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
      created_count: result['created_count'],
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