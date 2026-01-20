# frozen_string_literal: true

class MigrateAppuntiStatesToEntries < ActiveRecord::Migration[8.0]
  def up
    # =========================================
    # 1. Create Goldness for "in evidenza" appunti
    # =========================================
    execute <<-SQL
      INSERT INTO goldnesses (id, goldenable_type, goldenable_id, entry_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Appunto',
        a.id,
        e.id,
        a.user_id,
        a.account_id,
        a.updated_at,
        a.updated_at
      FROM appunti a
      INNER JOIN entries e ON e.entryable_type = 'Appunto' AND e.entryable_id = a.id::text
      WHERE a.stato = 'in evidenza'
      AND NOT EXISTS (
        SELECT 1 FROM goldnesses g
        WHERE g.entry_id = e.id
      );
    SQL

    # =========================================
    # 2. Create Closure for "completato" and "archiviato" appunti
    # =========================================
    execute <<-SQL
      INSERT INTO closures (id, closeable_type, closeable_id, entry_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Appunto',
        a.id,
        e.id,
        a.user_id,
        a.account_id,
        COALESCE(a.completed_at, a.updated_at),
        COALESCE(a.completed_at, a.updated_at)
      FROM appunti a
      INNER JOIN entries e ON e.entryable_type = 'Appunto' AND e.entryable_id = a.id::text
      WHERE a.stato IN ('completato', 'archiviato')
      AND NOT EXISTS (
        SELECT 1 FROM closures c
        WHERE c.entry_id = e.id
      );
    SQL

    # =========================================
    # 3. Create NotNow for "in visione" and "da pagare" appunti
    # =========================================
    execute <<-SQL
      INSERT INTO not_nows (id, not_nowable_type, not_nowable_id, entry_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Appunto',
        a.id,
        e.id,
        a.user_id,
        a.account_id,
        a.updated_at,
        a.updated_at
      FROM appunti a
      INNER JOIN entries e ON e.entryable_type = 'Appunto' AND e.entryable_id = a.id::text
      WHERE a.stato IN ('in visione', 'da pagare')
      AND NOT EXISTS (
        SELECT 1 FROM not_nows n
        WHERE n.entry_id = e.id
      );
    SQL
  end

  def down
    # Remove state records created by this migration
    # We identify them by checking if they're linked to appunti with matching states

    execute <<-SQL
      DELETE FROM goldnesses g
      USING entries e, appunti a
      WHERE g.entry_id = e.id
      AND e.entryable_type = 'Appunto'
      AND e.entryable_id = a.id::text
      AND a.stato = 'in evidenza';
    SQL

    execute <<-SQL
      DELETE FROM closures c
      USING entries e, appunti a
      WHERE c.entry_id = e.id
      AND e.entryable_type = 'Appunto'
      AND e.entryable_id = a.id::text
      AND a.stato IN ('completato', 'archiviato');
    SQL

    execute <<-SQL
      DELETE FROM not_nows n
      USING entries e, appunti a
      WHERE n.entry_id = e.id
      AND e.entryable_type = 'Appunto'
      AND e.entryable_id = a.id::text
      AND a.stato IN ('in visione', 'da pagare');
    SQL
  end
end
