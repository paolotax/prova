class UpdateMieAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account)
    # Reset all to false
    Adozione.where(account: account).update_all(mia: false)

    # Set mia = true where a mandato matches
    sql = <<~SQL
      UPDATE adozioni SET mia = true
      WHERE adozioni.account_id = :account_id
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND e.editore = adozioni.editore
          AND (m.provincia IS NULL OR m.provincia = s.provincia)
          AND (m.grado IS NULL OR m.grado = s.grado)
      )
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, account_id: account.id])
    )
  end
end
