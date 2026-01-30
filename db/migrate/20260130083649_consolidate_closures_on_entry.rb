class ConsolidateClosuresOnEntry < ActiveRecord::Migration[8.1]
  def up
    # =============================================================================
    # CONSOLIDAMENTO CLOSURES SU ENTRY
    # =============================================================================
    # Prima: closures puntavano a Tappa/Appunto/Documento via closeable_type/id
    # Dopo:  closures puntano a Entry via entry_id
    # =============================================================================

    # Step 0: Elimina closures duplicate (quando esiste sia via entry_id che via closeable)
    execute <<-SQL
      DELETE FROM closures
      WHERE id IN (
        SELECT c2.id
        FROM entries e
        INNER JOIN closures c1 ON c1.entry_id = e.id
        INNER JOIN closures c2 ON c2.closeable_type = e.entryable_type
                              AND c2.closeable_id = e.entryable_id
                              AND c2.entry_id IS NULL
      )
    SQL

    # Step 1: Aggiorna closures che hanno closeable_type ma non entry_id
    # Trova l'Entry corrispondente e imposta entry_id
    execute <<-SQL
      UPDATE closures
      SET entry_id = entries.id
      FROM entries
      WHERE closures.entry_id IS NULL
        AND closures.closeable_type IS NOT NULL
        AND closures.closeable_type = entries.entryable_type
        AND closures.closeable_id = entries.entryable_id
    SQL

    # Step 2: Verifica che tutte le closures abbiano entry_id
    orphan_count = execute(<<-SQL).first["count"]
      SELECT COUNT(*) as count
      FROM closures
      WHERE entry_id IS NULL
        AND closeable_type IS NOT NULL
    SQL

    if orphan_count > 0
      say "ATTENZIONE: #{orphan_count} closures orfane (senza Entry corrispondente)"
    end

    # Step 3: Rimuovi i riferimenti legacy (closeable_type/closeable_id)
    execute <<-SQL
      UPDATE closures
      SET closeable_type = NULL,
          closeable_id = NULL
      WHERE entry_id IS NOT NULL
    SQL

    # Step 4: Elimina closures orfane (senza entry_id dopo la migrazione)
    execute <<-SQL
      DELETE FROM closures
      WHERE entry_id IS NULL
    SQL

    say "Consolidamento completato: tutte le closures ora usano entry_id"
  end

  def down
    # Ripristina closeable_type/closeable_id dalle entries associate
    execute <<-SQL
      UPDATE closures
      SET closeable_type = entries.entryable_type,
          closeable_id = entries.entryable_id
      FROM entries
      WHERE closures.entry_id = entries.id
        AND closures.closeable_type IS NULL
    SQL

    say "Rollback completato: ripristinati closeable_type/closeable_id"
  end
end
