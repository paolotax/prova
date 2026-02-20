class BackfillDirezioniJob < ApplicationJob
  queue_as :bulk

  def perform(account)
    account.scuole.where(direzione_id: nil).includes(:import_scuola).find_each do |scuola|
      next unless scuola.import_scuola

      direzione = Scuola.resolve_direzione(scuola.import_scuola, account: account)
      scuola.update_column(:direzione_id, direzione.id) if direzione
    end
  end
end
