class BackfillDirezioniJob < ApplicationJob
  queue_as :bulk

  def perform(account)
    ids = account.scuole.where(direzione_id: nil).where.not(import_scuola_id: nil).pluck(:id)

    ids.each do |scuola_id|
      scuola = account.scuole.includes(:import_scuola).find_by(id: scuola_id)
      next unless scuola&.import_scuola
      next if scuola.direzione_id.present? # già collegata da un altro ciclo

      direzione = Scuola.resolve_direzione(scuola.import_scuola, account: account)
      scuola.update_column(:direzione_id, direzione.id) if direzione
    end
  end
end
