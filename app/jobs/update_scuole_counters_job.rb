class UpdateScuoleCountersJob < ApplicationJob
  queue_as :default

  def perform(account)
    update_classi_count(account)
    update_adozioni_count(account)
    update_mie_adozioni_count(account)
    reset_orphan_counters(account)
  end

  private

  def update_classi_count(account)
    sql = <<~SQL
      UPDATE scuole SET classi_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM classi c
        JOIN scuole s ON s.id = c.scuola_id
        WHERE s.account_id = :account_id
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql, account)
  end

  def update_adozioni_count(account)
    sql = <<~SQL
      UPDATE scuole SET adozioni_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM adozioni a
        JOIN classi c ON c.id = a.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE s.account_id = :account_id
          AND a.da_acquistare = true
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql, account)
  end

  def update_mie_adozioni_count(account)
    sql = <<~SQL
      UPDATE scuole SET mie_adozioni_count = sub.cnt
      FROM (
        SELECT c.scuola_id, COUNT(*) as cnt
        FROM adozioni a
        JOIN classi c ON c.id = a.classe_id
        JOIN scuole s ON s.id = c.scuola_id
        WHERE s.account_id = :account_id
          AND a.mia = true
          AND a.da_acquistare = true
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql, account)
  end

  def reset_orphan_counters(account)
    # Reset classi_count for scuole with no classi
    sql_classi = <<~SQL
      UPDATE scuole SET classi_count = 0
      WHERE scuole.account_id = :account_id
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM classi c
          JOIN scuole s ON s.id = c.scuola_id
          WHERE s.account_id = :account_id
        )
    SQL

    # Reset adozioni_count and mie_adozioni_count for scuole with no matching adozioni
    sql_adozioni = <<~SQL
      UPDATE scuole SET adozioni_count = 0, mie_adozioni_count = 0
      WHERE scuole.account_id = :account_id
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          JOIN scuole s ON s.id = c.scuola_id
          WHERE s.account_id = :account_id
            AND a.da_acquistare = true
        )
    SQL

    execute(sql_classi, account)
    execute(sql_adozioni, account)
  end

  def execute(sql, account)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, account_id: account.id])
    )
  end
end
