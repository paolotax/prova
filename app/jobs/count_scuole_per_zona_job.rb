class CountScuolePerZonaJob < ApplicationJob
  queue_as :bulk
  discard_on ActiveJob::DeserializationError

  include ActionView::RecordIdentifier

  def perform(account_zona)
    raise Miur::ImportError, "anno_corrente nil (miur_scuole vuota): conteggio zona abortito" if Miur.anno_corrente.nil?

    count = account_zona.miur_scuole_per_zona.count
    account_zona.update!(scuole_count: count, stato: "pronta")
    broadcast_zone_update(account_zona)
  end

  private

  def broadcast_zone_update(account_zona)
    account = account_zona.account
    account_zone = account.zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "accounts/zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end
end
