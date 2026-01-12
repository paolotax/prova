class ConvertAppuntiToUuid < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add uuid column to appunti
    add_column :appunti, :uuid, :uuid, default: -> { "gen_random_uuid()" }

    # Step 2: Backfill existing records with uuid
    execute "UPDATE appunti SET uuid = gen_random_uuid() WHERE uuid IS NULL"

    # Step 3: Add uuid reference column to appunto_righe
    add_column :appunto_righe, :appunto_uuid, :uuid

    # Step 4: Backfill appunto_righe with uuids
    execute <<-SQL
      UPDATE appunto_righe
      SET appunto_uuid = appunti.uuid
      FROM appunti
      WHERE appunto_righe.appunto_id = appunti.id
    SQL

    # Step 5: Remove old foreign key and constraints
    remove_foreign_key :appunto_righe, :appunti if foreign_key_exists?(:appunto_righe, :appunti)

    # Step 6: Drop old appunto_id from appunto_righe
    remove_column :appunto_righe, :appunto_id

    # Step 7: Rename appunto_uuid to appunto_id in appunto_righe
    rename_column :appunto_righe, :appunto_uuid, :appunto_id

    # Step 8: Add not null constraint and index
    change_column_null :appunto_righe, :appunto_id, false
    add_index :appunto_righe, :appunto_id unless index_exists?(:appunto_righe, :appunto_id)

    # Step 9: Now update appunti - drop old id, rename uuid to id
    # Remove primary key constraint
    execute "ALTER TABLE appunti DROP CONSTRAINT IF EXISTS appunti_pkey"

    # Drop the old id column
    remove_column :appunti, :id

    # Rename uuid to id
    rename_column :appunti, :uuid, :id

    # Add primary key constraint on uuid
    execute "ALTER TABLE appunti ADD PRIMARY KEY (id)"

    # Step 10: Update all indexes that referenced the old id
    add_index :appunti, :id, unique: true unless index_exists?(:appunti, :id, unique: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely revert UUID migration"
  end
end
