# Cancellazione utenti dall'admin. La cascata è lenta (account → scuole una
# a una, ognuna con le query di ProtectedFromDestroy più classi e persone):
# per account con migliaia di scuole servono minuti, quindi gira in
# background invece che nella richiesta web.
class DestroyUserJob < ApplicationJob
  include DestroyMarker
  include PurgaRigheOrfane

  queue_as :bulk

  # Errore deterministico (es. scuola con movimenti di record che non
  # dipendono dall'utente, o righe di documenti altrui sui libri): ritentare
  # non serve. Si toglie il marker così la UI riabilita il bottone.
  discard_on ActiveRecord::RecordNotDestroyed, ActiveRecord::InvalidForeignKey do |job, error|
    Rails.cache.delete(job.class.destroy_marker_key(job.arguments.first))
    Rails.logger.error("DestroyUserJob scartato per user #{job.arguments.first}: #{error.message}")
  end

  def perform(user_id)
    user = User.find_by(id: user_id)
    solo_account_ids = []

    if user
      ActiveRecord::Base.transaction do
        # Individuati prima della destroy dell'utente, che porta via le memberships
        solo_accounts = user.accounts.reject { |account| account.memberships.where.not(user_id: user.id).exists? }
        solo_account_ids = solo_accounts.map(&:id)

        # Prima l'utente: la sua cascata rimuove appunti, tappe e documenti
        # che altrimenti farebbero scattare ProtectedFromDestroy sulle scuole
        # degli account
        purga_righe(Libro.where(user_id: user.id), Documento.where(user_id: user.id))
        user.destroy!
        solo_accounts.each do |account|
          purga_righe(Libro.where(account_id: account.id), Documento.where(account_id: account.id))
          account.destroy!
        end
      end
    end

    Rails.cache.delete(self.class.destroy_marker_key(user_id))

    # Toglie le righe dalla lista admin aperta (accounts/index)
    Turbo::StreamsChannel.broadcast_remove_to(:admin_destroys, target: "user_#{user_id}")
    solo_account_ids.each do |account_id|
      Turbo::StreamsChannel.broadcast_remove_to(:admin_destroys, target: "account_#{account_id}")
    end
  end
end
