module Scuole
  module Classi
    class ClosedEntriesController < ApplicationController
      layout false

      before_action :set_scuola
      before_action :set_classe

      def show
        # Appunti della classe (escludi SSK)
        appunto_ids = @classe.appunti
                             .where.not(nome: %w[saggio seguito kit])
                             .pluck(:id).map(&:to_s)

        # Documenti della classe
        documento_ids = Documento.where(clientable: @classe)
                                 .pluck(:id).map(&:to_s)

        @closed_entries = Entry.where(account: Current.account)
                               .closed
                               .where(
                                 "(entryable_type = 'Appunto' AND entryable_id IN (?)) OR
                                  (entryable_type = 'Documento' AND entryable_id IN (?))",
                                 appunto_ids.presence || [""],
                                 documento_ids.presence || [""]
                               )
                               .includes(:goldness, :closure, :not_now)
                               .order(updated_at: :desc)

        Entry.load_entryables(@closed_entries)
      end

      private

      def set_scuola
        @scuola = Current.account.scuole.find(params[:scuola_id])
      end

      def set_classe
        @classe = @scuola.classi.find(params[:classe_id])
      end
    end
  end
end
