class CleanupZonaJob < ApplicationJob
  queue_as :bulk
  discard_on ActiveJob::DeserializationError

  def perform(account_zona)
    account = account_zona.account
    provincia = account_zona.provincia
    grado = account_zona.grado

    scuole_da_eliminare = account.scuole.where(provincia: provincia, grado: grado)
    direzione_ids = scuole_da_eliminare.where.not(direzione_id: nil).distinct.pluck(:direzione_id)

    # Destroy scuole una per una — quelle con appunti/documenti vengono skippate
    protette = []
    scuole_da_eliminare.find_each do |scuola|
      unless scuola.destroy
        protette << scuola
      end
    end

    # Elimina direzioni rimaste senza plessi (solo se non protette)
    if direzione_ids.any?
      account.scuole.where(id: direzione_ids).left_joins(:plessi)
        .where(plessi_scuole: { id: nil })
        .find_each do |direzione|
          unless direzione.destroy
            protette << direzione
          end
        end
    end

    if protette.any?
      # Scuole protette restano — zona rimane attiva con conteggio aggiornato
      remaining = account.scuole.where(provincia: provincia, grado: grado).count
      account_zona.update!(stato: "attiva", scuole_count: remaining)
      Rails.logger.info "[CleanupZona] #{protette.size} scuole protette (hanno appunti/documenti): #{protette.map(&:denominazione).join(', ')}"
    else
      account.mandati.where(provincia: provincia, grado: grado).destroy_all
      account_zona.destroy!
    end

    broadcast_zone_panel(account)
    broadcast_scuole_refresh(account)
    UpdateMieAdozioniJob.perform_later(account)
  end

  private

  def broadcast_zone_panel(account)
    account_zone = account.zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "accounts/zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end

  def broadcast_scuole_refresh(account)
    account.memberships.find_each do |membership|
      Turbo::StreamsChannel.broadcast_refresh_later_to(membership, "scuole")
    end
  end
end
