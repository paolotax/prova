# Controller per entries nested sotto scuole
# Mostra entries attive (Appunti e Documenti) per una scuola
module Scuole
  class EntriesController < ApplicationController
    layout false
    before_action :set_scuola

    def show
      # IDs delle classi della scuola
      classe_ids = @scuola.classi.pluck(:id)

      # Appunti: scuola + classi (solo pubblicati)
      appunti_scuola = @scuola.appunti.published
      appunti_classi = Appunto.published.where(appuntabile_type: "Classe", appuntabile_id: classe_ids)
      appunto_ids = (appunti_scuola.pluck(:id) + appunti_classi.pluck(:id)).map(&:to_s)

      # Documenti: scuola + classi
      documenti_scuola = Documento.where(clientable: @scuola)
      documenti_classi = Documento.where(clientable_type: "Classe", clientable_id: classe_ids)
      documento_ids = (documenti_scuola.pluck(:id) + documenti_classi.pluck(:id)).map(&:to_s)

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
        @appunti = Appunto.where(id: appunto_ids).attivi.order(updated_at: :desc).limit(5)
        @documenti = Documento.where(id: documento_ids).order(updated_at: :desc).limit(5)
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
