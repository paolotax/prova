class CleanupZonaJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(account_zona)
    account = account_zona.account
    provincia = account_zona.provincia
    grado = account_zona.grado

    # Raccogli le direzioni referenziate dalle scuole che stiamo per eliminare
    scuole_da_eliminare = account.scuole.where(provincia: provincia, grado: grado)
    direzione_ids = scuole_da_eliminare.where.not(direzione_id: nil).distinct.pluck(:direzione_id)

    # Destroy scuole della zona (cascades to classi -> adozioni via dependent: :destroy)
    # has_many :plessi ha dependent: :nullify, quindi le direzioni restano
    scuole_da_eliminare.destroy_all

    # Elimina direzioni rimaste senza plessi
    if direzione_ids.any?
      account.scuole.where(id: direzione_ids).left_joins(:plessi)
        .where(plessi_scuole: { id: nil })
        .destroy_all
    end

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
