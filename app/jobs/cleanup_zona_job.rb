class CleanupZonaJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  include ActionView::RecordIdentifier

  def perform(account_zona)
    account = account_zona.account
    provincia = account_zona.provincia
    grado = account_zona.grado

    # Destroy scuole (cascades to classi → adozioni via dependent: :destroy)
    account.scuole.where(provincia: provincia, grado: grado).destroy_all

    # Remove zona from UI via broadcast, then destroy the record
    broadcast_zona_remove(account, account_zona)
    account_zona.destroy!
  end

  private

  def broadcast_zona_remove(account, account_zona)
    Turbo::StreamsChannel.broadcast_remove_to(
      [account, "configurazione"],
      target: dom_id(account_zona)
    )
  end
end
