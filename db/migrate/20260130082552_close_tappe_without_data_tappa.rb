class CloseTappeWithoutDataTappa < ActiveRecord::Migration[8.1]
  def up
    # Chiude tutte le tappe senza data_tappa create più di un anno fa
    execute <<-SQL
      INSERT INTO closures (id, closeable_type, closeable_id, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Tappa',
        t.id::text,
        t.account_id,
        t.user_id,
        t.created_at,
        NOW()
      FROM tappe t
      WHERE t.data_tappa IS NULL
        AND t.created_at < CURRENT_DATE - INTERVAL '1 year'
        AND NOT EXISTS (
          SELECT 1 FROM closures c
          WHERE c.closeable_type = 'Tappa' AND c.closeable_id = t.id::text
        )
    SQL
  end

  def down
    # Rimuove solo le closure delle tappe senza data_tappa vecchie di un anno
    execute <<-SQL
      DELETE FROM closures
      WHERE closeable_type = 'Tappa'
        AND closeable_id IN (
          SELECT id::text FROM tappe
          WHERE data_tappa IS NULL
            AND created_at < CURRENT_DATE - INTERVAL '1 year'
        )
    SQL
  end
end
