class ConsolidateNotNowsOnEntry < ActiveRecord::Migration[8.1]
  def up
    # Step 0: Elimina not_nows duplicate (quando esiste sia via entry_id che via not_nowable)
    execute <<-SQL
      DELETE FROM not_nows
      WHERE id IN (
        SELECT n2.id
        FROM entries e
        INNER JOIN not_nows n1 ON n1.entry_id = e.id
        INNER JOIN not_nows n2 ON n2.not_nowable_type = e.entryable_type
                              AND n2.not_nowable_id::text = e.entryable_id
                              AND n2.entry_id IS NULL
      )
    SQL

    # Step 1: Aggiorna not_nows che hanno not_nowable_type ma non entry_id
    execute <<-SQL
      UPDATE not_nows
      SET entry_id = entries.id
      FROM entries
      WHERE not_nows.entry_id IS NULL
        AND not_nows.not_nowable_type IS NOT NULL
        AND not_nows.not_nowable_type = entries.entryable_type
        AND not_nows.not_nowable_id::text = entries.entryable_id
    SQL

    # Step 2: Rimuovi i riferimenti legacy
    execute <<-SQL
      UPDATE not_nows
      SET not_nowable_type = NULL,
          not_nowable_id = NULL
      WHERE entry_id IS NOT NULL
    SQL

    # Step 3: Elimina not_nows orfane
    execute <<-SQL
      DELETE FROM not_nows
      WHERE entry_id IS NULL
    SQL

    say "Consolidamento not_nows completato"
  end

  def down
    execute <<-SQL
      UPDATE not_nows
      SET not_nowable_type = entries.entryable_type,
          not_nowable_id = entries.entryable_id::uuid
      FROM entries
      WHERE not_nows.entry_id = entries.id
        AND not_nows.not_nowable_type IS NULL
    SQL
  end
end
