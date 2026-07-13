# Cancellazione account dall'admin. Oltre alla cascata di Account (scuole,
# documenti, entries, ...) vanno rimossi prima i dati per-utente scoperti
# sull'account e fuori dalla sua cascata: hanno FK su accounts e le tappe
# proteggono le scuole via ProtectedFromDestroy. I membri restano come
# utenti registrati.
class DestroyAccountJob < ApplicationJob
  include DestroyMarker
  include PurgaRigheOrfane

  queue_as :bulk

  discard_on ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey do |job, error|
    Rails.cache.delete(job.class.destroy_marker_key(job.arguments.first))
    Rails.logger.error("DestroyAccountJob scartato per account #{job.arguments.first}: #{error.message}")
  end

  def perform(account_id)
    account = Account.find_by(id: account_id)

    if account
      ActiveRecord::Base.transaction do
        destroy_dati_utente(account)
        purga_righe(Libro.where(account_id: account.id), Documento.where(account_id: account.id))
        account.destroy!
      end
    end

    Rails.cache.delete(self.class.destroy_marker_key(account_id))

    # Toglie la riga dalla lista admin aperta (accounts/index)
    Turbo::StreamsChannel.broadcast_remove_to(:admin_destroys, target: "account_#{account_id}")
  end

  private

    def destroy_dati_utente(account)
      Tappa.where(account_id: account.id).find_each(&:destroy!)
      # Tappe orfane di ALTRI account che puntano alle scuole di questo
      # (residui di test cross-account): senza le scuole sarebbero rotte,
      # e intanto le proteggono via ProtectedFromDestroy
      Tappa.where(tappable_type: "Scuola", tappable_id: account.scuole.select(:id)).find_each(&:destroy!)
      Giro.where(account_id: account.id).find_each(&:destroy!)
      Chat.where(account_id: account.id).find_each(&:destroy!)
      Sconto.where(account_id: account.id).destroy_all
      ::Filters::Base.where(account_id: account.id).destroy_all
      Registrazione.where(account_id: account.id).destroy_all
      CattedraDisciplina.where(account_id: account.id).destroy_all
    end
end
