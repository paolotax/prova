class UpdateScuoleCountersJob < ApplicationJob
  queue_as :default

  def perform(account, provincia: nil)
    @provincia_clause = provincia ? "AND s.provincia = :provincia" : ""
    @sql_params = { account_id: account.id }
    @sql_params[:provincia] = provincia if provincia

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
          AND c.stato = 'attiva'
          #{@provincia_clause}
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql)
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
          AND c.stato = 'attiva'
          AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
          #{@provincia_clause}
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql)
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
          AND c.stato = 'attiva'
          AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
          #{@provincia_clause}
        GROUP BY c.scuola_id
      ) sub
      WHERE scuole.id = sub.scuola_id
        AND scuole.account_id = :account_id
    SQL

    execute(sql)
  end

  def reset_orphan_counters(account)
    # Reset classi_count for scuole with no classi
    sql_classi = <<~SQL
      UPDATE scuole SET classi_count = 0
      WHERE scuole.account_id = :account_id
        #{@provincia_clause.gsub("s.", "scuole.")}
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM classi c
          JOIN scuole s ON s.id = c.scuola_id
          WHERE s.account_id = :account_id
            AND c.stato = 'attiva'
            #{@provincia_clause}
        )
    SQL

    # Reset adozioni_count for scuole with no adozioni da_acquistare
    sql_adozioni = <<~SQL
      UPDATE scuole SET adozioni_count = 0
      WHERE scuole.account_id = :account_id
        #{@provincia_clause.gsub("s.", "scuole.")}
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          JOIN scuole s ON s.id = c.scuola_id
          WHERE s.account_id = :account_id
            AND a.da_acquistare = true
            AND c.stato = 'attiva'
            AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
            #{@provincia_clause}
        )
    SQL

    # Reset mie_adozioni_count for scuole with no adozioni mia+da_acquistare
    sql_mie_adozioni = <<~SQL
      UPDATE scuole SET mie_adozioni_count = 0
      WHERE scuole.account_id = :account_id
        #{@provincia_clause.gsub("s.", "scuole.")}
        AND scuole.id NOT IN (
          SELECT DISTINCT c.scuola_id FROM adozioni a
          JOIN classi c ON c.id = a.classe_id
          JOIN scuole s ON s.id = c.scuola_id
          WHERE s.account_id = :account_id
            AND a.mia = true
            AND a.da_acquistare = true
            AND c.stato = 'attiva'
            AND a.anno_scolastico IS NOT DISTINCT FROM c.anno_scolastico
            #{@provincia_clause}
        )
    SQL

    execute(sql_classi)
    execute(sql_adozioni)
    execute(sql_mie_adozioni)
  end

  def execute(sql)
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, @sql_params])
    )
  end
end
