class BackfillDirezioniJob < ApplicationJob
  queue_as :bulk

  def perform(account)
    ids = account.scuole.where(direzione_id: nil).where.not(import_scuola_id: nil).pluck(:id)

    ids.each_slice(100) do |batch_ids|
      account.scuole.where(id: batch_ids).includes(:import_scuola).each do |scuola|
        direzione = Scuola.resolve_direzione(scuola.import_scuola, account: account)
        scuola.update_column(:direzione_id, direzione.id) if direzione
      end
    end
  end
end
