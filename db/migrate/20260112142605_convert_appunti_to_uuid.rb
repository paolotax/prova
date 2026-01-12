class ConvertAppuntiToUuid < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add uuid column to appunti
    add_column :appunti, :uuid, :uuid, default: -> { "gen_random_uuid()" }

    # Step 2: Backfill existing records with uuid
    execute "UPDATE appunti SET uuid = gen_random_uuid() WHERE uuid IS NULL"

    # Step 3: Convert polymorphic record_id to string to support both bigint and uuid
    # This allows mixed ID types across different models
    change_column :active_storage_attachments, :record_id, :string
    change_column :action_text_rich_texts, :record_id, :string

    # Step 4: Update active_storage_attachments with new uuid for Appunto records
    execute <<-SQL
      UPDATE active_storage_attachments
      SET record_id = appunti.uuid::text
      FROM appunti
      WHERE active_storage_attachments.record_type = 'Appunto'
        AND active_storage_attachments.record_id = appunti.id::text
    SQL

    # Step 5: Update action_text_rich_texts with new uuid for Appunto records
    execute <<-SQL
      UPDATE action_text_rich_texts
      SET record_id = appunti.uuid::text
      FROM appunti
      WHERE action_text_rich_texts.record_type = 'Appunto'
        AND action_text_rich_texts.record_id = appunti.id::text
    SQL

    # Step 6: Add uuid reference column to appunto_righe
    add_column :appunto_righe, :appunto_uuid, :uuid

    # Step 7: Backfill appunto_righe with uuids
    execute <<-SQL
      UPDATE appunto_righe
      SET appunto_uuid = appunti.uuid
      FROM appunti
      WHERE appunto_righe.appunto_id = appunti.id
    SQL

    # Step 8: Remove old foreign key and constraints
    remove_foreign_key :appunto_righe, :appunti if foreign_key_exists?(:appunto_righe, :appunti)

    # Step 9: Drop old appunto_id from appunto_righe
    remove_column :appunto_righe, :appunto_id

    # Step 10: Rename appunto_uuid to appunto_id in appunto_righe
    rename_column :appunto_righe, :appunto_uuid, :appunto_id

    # Step 11: Add not null constraint and index
    change_column_null :appunto_righe, :appunto_id, false
    add_index :appunto_righe, :appunto_id unless index_exists?(:appunto_righe, :appunto_id)

    # Step 12: Now update appunti - drop old id, rename uuid to id
    # Remove primary key constraint
    execute "ALTER TABLE appunti DROP CONSTRAINT IF EXISTS appunti_pkey"

    # Drop the old id column
    remove_column :appunti, :id

    # Rename uuid to id
    rename_column :appunti, :uuid, :id

    # Add primary key constraint on uuid
    execute "ALTER TABLE appunti ADD PRIMARY KEY (id)"

    # Step 13: Update all indexes that referenced the old id
    add_index :appunti, :id, unique: true unless index_exists?(:appunti, :id, unique: true)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot safely revert UUID migration"
  end
end
