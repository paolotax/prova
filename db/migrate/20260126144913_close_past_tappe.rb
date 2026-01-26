class ClosePastTappe < ActiveRecord::Migration[8.1]
  def up
    # Chiude tutte le tappe con data_tappa nel passato
    execute <<-SQL
      INSERT INTO closures (id, closeable_type, closeable_id, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Tappa',
        t.id::text,
        t.account_id,
        t.user_id,
        COALESCE(t.data_tappa::timestamp, NOW()),
        NOW()
      FROM tappe t
      WHERE t.data_tappa < CURRENT_DATE
        AND NOT EXISTS (
          SELECT 1 FROM closures c
          WHERE c.closeable_type = 'Tappa' AND c.closeable_id = t.id::text
        )
    SQL
  end

  def down
    execute "DELETE FROM closures WHERE closeable_type = 'Tappa'"
  end
end
