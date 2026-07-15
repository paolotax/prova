class ImportScuolePerZonaJob < ApplicationJob
  queue_as :bulk
  discard_on ActiveJob::DeserializationError

  include BroadcastsPulsanteAggiornaAdozioni

  # Import zona dal ministeriale: anagrafe da miur_scuole (anno corrente),
  # classi+adozioni via Adozione::Reconciler per (provincia, anno) su anno
  # corrente + precedente (lo storico nasce archiviato, regola del Reconciler).
  # Idempotente: il Reconciler protegge i dati utente e l'anagrafe e'
  # ON CONFLICT DO NOTHING.
  def perform(account_zona)
    corrente = AnnoScolastico.corrente
    raise Miur::ImportError, "anno_corrente nil (miur_scuole vuota): import zona abortito" if corrente.nil?

    account = account_zona.account
    Current.account = account
    account_zona.update!(stato: "importazione")

    miur_scuole = account_zona.miur_scuole_per_zona.to_a
    Scuola::AnagrafeMiur.new(account: account, miur_scuole: miur_scuole, anno: corrente.to_s).call

    [corrente.precedente.to_s, corrente.to_s].each do |anno|
      Adozione::Reconciler.new(account: account, provincia: account_zona.provincia, anno: anno).call
    end

    account_zona.update!(scuole_count: miur_scuole.size, stato: "attiva")
    account.estendi_mandati_a_zona!(provincia: account_zona.provincia, grado: account_zona.grado)
    broadcast_zone_panel(account)
    broadcast_scuole_refresh(account)
    broadcast_pulsante_stato(account)
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
