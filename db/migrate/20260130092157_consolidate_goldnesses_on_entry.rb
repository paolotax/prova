class ConsolidateGoldnessesOnEntry < ActiveRecord::Migration[8.1]
  def up
    # Step 0: Elimina goldnesses duplicate (quando esiste sia via entry_id che via goldenable)
    execute <<-SQL
      DELETE FROM goldnesses
      WHERE id IN (
        SELECT g2.id
        FROM entries e
        INNER JOIN goldnesses g1 ON g1.entry_id = e.id
        INNER JOIN goldnesses g2 ON g2.goldenable_type = e.entryable_type
                                AND g2.goldenable_id::text = e.entryable_id
                                AND g2.entry_id IS NULL
      )
    SQL

    # Step 1: Aggiorna goldnesses che hanno goldenable_type ma non entry_id
    execute <<-SQL
      UPDATE goldnesses
      SET entry_id = entries.id
      FROM entries
      WHERE goldnesses.entry_id IS NULL
        AND goldnesses.goldenable_type IS NOT NULL
        AND goldnesses.goldenable_type = entries.entryable_type
        AND goldnesses.goldenable_id::text = entries.entryable_id
    SQL

    # Step 2: Rimuovi i riferimenti legacy
    execute <<-SQL
      UPDATE goldnesses
      SET goldenable_type = NULL,
          goldenable_id = NULL
      WHERE entry_id IS NOT NULL
    SQL

    # Step 3: Elimina goldnesses orfane
    execute <<-SQL
      DELETE FROM goldnesses
      WHERE entry_id IS NULL
    SQL

    say "Consolidamento goldnesses completato"
  end

  def down
    execute <<-SQL
      UPDATE goldnesses
      SET goldenable_type = entries.entryable_type,
          goldenable_id = entries.entryable_id::uuid
      FROM entries
      WHERE goldnesses.entry_id = entries.id
        AND goldnesses.goldenable_type IS NULL
    SQL
  end
end
