# Controller per entries nested sotto scuole
# Mostra entries attive e completate (Appunti e Documenti) per una scuola
module Scuole
  class EntriesController < ApplicationController
    layout false
    before_action :set_scuola

    def show
      appunto_ids, documento_ids = entryable_ids

      @entries = Entry.where(account: Current.account)
                      .aperti
                      .where(
                        "(entryable_type = 'Appunto' AND entryable_id IN (?)) OR
                         (entryable_type = 'Documento' AND entryable_id IN (?))",
                        appunto_ids.presence || [""],
                        documento_ids.presence || [""]
                      )
                      .includes(:goldness, :closure, :not_now)
                      .order(updated_at: :desc)

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

    def entryable_ids
      classe_ids = @scuola.classi.pluck(:id)

      appunto_ids = (@scuola.appunti.published.pluck(:id) +
                     Appunto.published.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).pluck(:id))
                    .map(&:to_s)

      documento_ids = (Documento.where(clientable: @scuola).pluck(:id) +
                       Documento.where(clientable_type: "Classe", clientable_id: classe_ids).pluck(:id))
                      .map(&:to_s)

      [appunto_ids, documento_ids]
    end
  end
end
