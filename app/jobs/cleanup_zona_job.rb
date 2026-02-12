class CleanupZonaJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(account_zona)
    account = account_zona.account
    provincia = account_zona.provincia
    grado = account_zona.grado

    # Destroy scuole (cascades to classi -> adozioni via dependent: :destroy)
    account.scuole.where(provincia: provincia, grado: grado).destroy_all
    account_zona.destroy!

    broadcast_zone_panel(account)
  end

  private

  def broadcast_zone_panel(account)
    account_zone = account.account_zone.order(:provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end
end
