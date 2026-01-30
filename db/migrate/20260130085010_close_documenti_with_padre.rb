class CloseDocumentiWithPadre < ActiveRecord::Migration[8.1]
  def up
    # Chiude tutti i documenti che hanno un documento padre (es. DDT figlio di TD01)
    # La data di chiusura è la data del documento figlio
    execute <<-SQL
      INSERT INTO closures (id, entry_id, account_id, user_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        e.id,
        e.account_id,
        e.user_id,
        COALESCE(d.data_documento::timestamp, d.created_at),
        NOW()
      FROM documenti d
      INNER JOIN entries e ON e.entryable_type = 'Documento'
                          AND e.entryable_id = d.id::text
      WHERE d.documento_padre_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM closures c
          WHERE c.entry_id = e.id
        )
    SQL

    count = execute("SELECT COUNT(*) FROM closures c INNER JOIN entries e ON c.entry_id = e.id INNER JOIN documenti d ON e.entryable_id = d.id::text WHERE d.documento_padre_id IS NOT NULL").first["count"]
    say "Chiusi #{count} documenti con padre"
  end

  def down
    # Riapre i documenti con padre
    execute <<-SQL
      DELETE FROM closures
      WHERE entry_id IN (
        SELECT e.id
        FROM entries e
        INNER JOIN documenti d ON e.entryable_type = 'Documento'
                              AND e.entryable_id = d.id::text
        WHERE d.documento_padre_id IS NOT NULL
      )
    SQL
  end
end
