module Scuole
  module Classi
    class EntriesController < ApplicationController
      layout false

      before_action :set_scuola
      before_action :set_classe

      def show
        appunto_ids = @classe.appunti.published.pluck(:id).map(&:to_s)

        # Documenti della classe
        documento_ids = Documento.where(clientable: @classe)
                                 .pluck(:id).map(&:to_s)

        @entries = Entry.where(account: Current.account)
                        .active
                        .where(
                          "(entryable_type = 'Appunto' AND entryable_id IN (?)) OR
                           (entryable_type = 'Documento' AND entryable_id IN (?))",
                          appunto_ids.presence || [""],
                          documento_ids.presence || [""]
                        )
                        .includes(:goldness, :closure, :not_now)
                        .order(updated_at: :desc)
                        .limit(10)

        if @entries.empty?
          @appunti = Appunto.where(id: appunto_ids).attivi.order(updated_at: :desc).limit(5)
          @documenti = Documento.where(id: documento_ids).order(updated_at: :desc).limit(5)
        end
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
