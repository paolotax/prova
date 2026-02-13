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

      import = Current.user.import_records.new(
        import_type: :insegnanti,
        account: current_account,
        file: params[:file],
        metadata: { scuola_id: @scuola.id, scuola_nome: @scuola.denominazione }
      )

      if import.save
        ImportProcessJob.perform_later(import.id)
        redirect_to import_path(import), notice: "Importazione insegnanti avviata."
      else
        redirect_to @scuola, alert: "Errore nell'avvio dell'importazione."
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
