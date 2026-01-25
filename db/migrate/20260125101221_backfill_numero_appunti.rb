class BackfillNumeroAppunti < ActiveRecord::Migration[8.0]
  def up
    execute <<-SQL
      WITH numbered_appunti AS (
        SELECT
          id,
          ROW_NUMBER() OVER (
            PARTITION BY account_id, EXTRACT(YEAR FROM created_at)
            ORDER BY created_at
          ) AS nuovo_numero
        FROM appunti
        WHERE numero IS NULL
      )
      UPDATE appunti
      SET numero = numbered_appunti.nuovo_numero
      FROM numbered_appunti
      WHERE appunti.id = numbered_appunti.id
    SQL
  end

  def down
    execute "UPDATE appunti SET numero = NULL"
  end
end
