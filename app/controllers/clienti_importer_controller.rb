class ClientiImporterController < ApplicationController
  include ActionView::Helpers::TextHelper
  before_action :authenticate_user!

  def show
    @import = ClientiImporter.new
    @result = session.delete(:import_result)
  end

  def create
    @import = ClientiImporter.new(clienti_importer_params)
    @import.save

    session[:import_result] = {
      imported_count: @import.imported_count,
      updated_count: @import.updated_count,
      errors_count: @import.errors_count,
      errors: @import.errors.full_messages,
      success: @import.errors.none?
    }

    redirect_to clienti_importer_path
  end

  private

  def clienti_importer_params
    params.require(:clienti_importer).permit(:file, :import_method)
  end
end
