class UpdateMieAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account)
    # Reset all
    Adozione.where(account: account).update_all(mia: false, disdetta: false)

    # Set mia = true where a mandato matches (active or disdetto)
    sql_mia = <<~SQL
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
      ActiveRecord::Base.sanitize_sql([sql_mia, account_id: account.id])
    )

    # Set disdetta = true where matching mandato is disdetto
    sql_disdetta = <<~SQL
      UPDATE adozioni SET disdetta = true
      WHERE adozioni.account_id = :account_id
      AND adozioni.mia = true
      AND EXISTS (
        SELECT 1 FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN classi c ON c.id = adozioni.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = adozioni.account_id
          AND m.disdetta = true
          AND e.editore = adozioni.editore
          AND (m.provincia IS NULL OR m.provincia = s.provincia)
          AND (m.grado IS NULL OR m.grado = s.grado)
      )
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql_disdetta, account_id: account.id])
    )

    # Update sezioni_count on each mandato
    update_sezioni_counts(account)

    broadcast_mandati_update(account)
  end

  private

  def update_sezioni_counts(account)
    # Reset all counts
    account.mandati.update_all(sezioni_count: 0)

    # Set counts from mia adozioni
    sql = <<~SQL
      UPDATE mandati SET sezioni_count = sub.cnt
      FROM (
        SELECT m.id, COUNT(DISTINCT a.classe_id) as cnt
        FROM mandati m
        JOIN editori e ON e.id = m.editore_id
        JOIN adozioni a ON a.account_id = m.account_id AND a.editore = e.editore AND a.mia = true
        JOIN classi c ON c.id = a.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE m.account_id = :account_id
          AND (m.provincia IS NULL OR m.provincia = s.provincia)
          AND (m.grado IS NULL OR m.grado = s.grado)
        GROUP BY m.id
      ) sub
      WHERE mandati.id = sub.id
    SQL

    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, account_id: account.id])
    )
  end

  def broadcast_mandati_update(account)
    mandati = account.mandati.includes(:editore).order("editori.editore")

    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "account-editori",
      partial: "mandati/mandati_list",
      locals: { mandati: mandati }
    )
  end
end
