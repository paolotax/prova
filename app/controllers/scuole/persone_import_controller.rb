module Scuole
  class PersoneImportController < ApplicationController
    before_action :set_scuola

    def new
    end

    def create
      unless params[:file]&.content_type == "application/pdf"
        redirect_to @scuola, alert: "Seleziona un file PDF."
        return
      end

      importer = AnarpeImporter.new(file: params[:file].tempfile, scuola: @scuola)
      importer.call

      if importer.errors_list.any?
        redirect_to @scuola, alert: "Importati #{importer.imported_count} insegnanti, #{importer.errors_list.size} errori."
      else
        redirect_to @scuola, notice: "Importati #{importer.imported_count} insegnanti."
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
