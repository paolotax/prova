class ImportScuolePerZonaJob < ApplicationJob
  queue_as :default
  discard_on ActiveJob::DeserializationError

  include ActionView::RecordIdentifier

  def perform(account_zona)
    account = account_zona.account
    account_zona.update!(stato: "importazione")

    count = 0
    account_zona.import_scuole_per_zona.find_each do |import_scuola|
      scuola = Scuola.find_or_create_from_import(import_scuola, account: account)

      Views::Classe.where(codice_ministeriale: import_scuola.CODICESCUOLA).find_each do |view_classe|
        classe = Classe.find_or_create_from_view(view_classe, scuola: scuola, account: account)
        Adozione.import_for_classe(classe)
      end
      count += 1
    end

    account_zona.update!(scuole_count: count, stato: "attiva")
    broadcast_zone_panel(account)
    UpdateMieAdozioniJob.perform_later(account)
  end

  private

  def broadcast_zone_panel(account)
    account_zone = account.account_zone.order(:regione, :provincia, :grado)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "zone-panel",
      partial: "zone/zone_list",
      locals: { account_zone: account_zone }
    )
  end
end
