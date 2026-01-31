# Controller per entries nested sotto scuole
# Mostra entries attive (Appunti e Documenti) per una scuola
module Scuole
  class EntriesController < ApplicationController
    layout false
    before_action :set_scuola

    def show
      # Escludi appunti SSK (saggio, seguito, kit)
      appunti_non_ssk = @scuola.appunti.where.not(nome: %w[saggio seguito kit])
      appunto_ids = appunti_non_ssk.pluck(:id).map(&:to_s)
      documento_ids = Documento.where(clientable: @scuola).pluck(:id).map(&:to_s)

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

      # Fallback: carica direttamente appunti/documenti se no entries
      if @entries.empty?
        @appunti = appunti_non_ssk.attivi.order(updated_at: :desc).limit(5)
        @documenti = Documento.where(clientable: @scuola)
                              .order(updated_at: :desc).limit(5)
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
