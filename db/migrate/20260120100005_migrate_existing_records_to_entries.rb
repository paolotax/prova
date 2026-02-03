# frozen_string_literal: true

class MigrateExistingRecordsToEntries < ActiveRecord::Migration[8.0]
  def up
    # =========================================
    # 1. Create default columns for all accounts
    # =========================================
    execute <<-SQL
      INSERT INTO columns (id, name, color, position, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        col.name,
        col.color,
        col.position,
        accounts.id,
        NOW(),
        NOW()
      FROM accounts
      CROSS JOIN (
        VALUES
          ('Nel Baule', '#22c55e', 0),
          ('La prossima settimana', '#f97316', 1)
      ) AS col(name, color, position)
      WHERE NOT EXISTS (
        SELECT 1 FROM columns
        WHERE columns.account_id = accounts.id
        AND columns.name = col.name
      );
          ('Consegna Vacanze', '#3b82f6', 2),
          ('Ritiro Vacanze', '#8b5cf6', 3)
    SQL

    # =========================================
    # 2. Create Entry for each Appunto
    # =========================================
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Appunto',
        appunti.id::text,
        appunti.user_id,
        appunti.account_id,
        appunti.created_at,
        appunti.updated_at
      FROM appunti
      WHERE appunti.account_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Appunto'
        AND entries.entryable_id = appunti.id::text
      );
    SQL

    # =========================================
    # 3. Create Entry for each Documento
    # =========================================
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Documento',
        documenti.id::text,
        documenti.user_id,
        documenti.account_id,
        documenti.created_at,
        documenti.updated_at
      FROM documenti
      WHERE documenti.account_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Documento'
        AND entries.entryable_id = documenti.id::text
      );
    SQL

    # =========================================
    # 4. Create Entry for each Tappa
    # =========================================
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, giro_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Tappa',
        t.id::text,
        t.giro_id,
        t.user_id,
        t.account_id,
        t.created_at,
        t.updated_at
      FROM tappe t
      WHERE t.account_id IS NOT NULL
      AND t.user_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Tappa'
        AND entries.entryable_id = t.id::text
      );
    SQL

    # =========================================
    # 5. Migrate goldnesses to entries (for Appunto only, since only Appunto uses Golden)
    # =========================================
    execute <<-SQL
      UPDATE goldnesses g
      SET entry_id = e.id
      FROM entries e
      WHERE e.entryable_type = g.goldenable_type
      AND e.entryable_id = g.goldenable_id::text
      AND g.entry_id IS NULL;
    SQL

    # =========================================
    # 6. Migrate closures to entries
    # =========================================
    execute <<-SQL
      UPDATE closures c
      SET entry_id = e.id
      FROM entries e
      WHERE e.entryable_type = c.closeable_type
      AND e.entryable_id = c.closeable_id::text
      AND c.entry_id IS NULL;
    SQL

    # =========================================
    # 7. Migrate not_nows to entries
    # =========================================
    execute <<-SQL
      UPDATE not_nows n
      SET entry_id = e.id
      FROM entries e
      WHERE e.entryable_type = n.not_nowable_type
      AND e.entryable_id = n.not_nowable_id::text
      AND n.entry_id IS NULL;
    SQL
  end

  def down
    # Remove entries (but keep the original records)
    execute "DELETE FROM entries;"

    # Clear entry_id from state records
    execute "UPDATE goldnesses SET entry_id = NULL;"
    execute "UPDATE closures SET entry_id = NULL;"
    execute "UPDATE not_nows SET entry_id = NULL;"

    # Remove default columns
    execute <<-SQL
      DELETE FROM columns
      WHERE name IN ('Consegna Collana', 'Ritiro Collana', 'Consegna Vacanze', 'Ritiro Vacanze');
    SQL
  end
end
