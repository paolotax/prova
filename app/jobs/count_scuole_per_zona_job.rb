class CountScuolePerZonaJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  include ActionView::RecordIdentifier

  def perform(account_zona)
    count = account_zona.import_scuole_per_zona.count
    account_zona.update!(scuole_count: count, stato: "pronta")
    broadcast_zone_update(account_zona)
  end

  private

  def broadcast_zone_update(account_zona)
    account = account_zona.account
    account_zone = account.account_zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end
end
