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

    broadcast_mandati_update(account)
  end

  private

  def broadcast_mandati_update(account)
    mandati = account.mandati.includes(:editore).order("editori.editore")
    conteggi = conteggi_per_mandato(account)

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "account-editori",
      partial: "mandati/mandati_list",
      locals: { mandati: mandati, conteggi: conteggi }
    )
  end

  def conteggi_per_mandato(account)
    sql = <<~SQL
      SELECT m.id, COUNT(DISTINCT a.classe_id) as sezioni_count
      FROM mandati m
      JOIN editori e ON e.id = m.editore_id
      JOIN adozioni a ON a.account_id = m.account_id AND a.editore = e.editore AND a.mia = true
      JOIN classi c ON c.id = a.classe_id
      JOIN scuole s ON s.id = c.scuola_id
      WHERE m.account_id = :account_id
        AND (m.provincia IS NULL OR m.provincia = s.provincia)
        AND (m.grado IS NULL OR m.grado = s.grado)
      GROUP BY m.id
    SQL

    result = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, account_id: account.id])
    )
    result.each_with_object({}) { |row, h| h[row["id"]] = row["sezioni_count"] }
  end
end
