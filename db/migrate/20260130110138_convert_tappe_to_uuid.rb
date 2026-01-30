class ConvertTappeToUuid < ActiveRecord::Migration[8.1]
  def up
    # 1. Drop foreign keys che referenziano tappe
    remove_foreign_key :tappa_giri, :tappe, if_exists: true

    # 2. Aggiungi colonne UUID temporanee
    add_column :tappe, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :tappa_giri, :tappa_uuid, :uuid

    # 3. Crea mapping table temporanea per old_id -> new_uuid
    execute <<-SQL
      CREATE TEMPORARY TABLE tappe_id_map AS
      SELECT id AS old_id, uuid AS new_uuid FROM tappe
    SQL

    # 4. Popola tappa_uuid in tappa_giri
    execute <<-SQL
      UPDATE tappa_giri tg
      SET tappa_uuid = m.new_uuid
      FROM tappe_id_map m
      WHERE tg.tappa_id = m.old_id
    SQL

    # 5. Aggiorna entries per Tappa con i nuovi UUID
    execute <<-SQL
      UPDATE entries e
      SET entryable_id = m.new_uuid::text
      FROM tappe_id_map m
      WHERE e.entryable_type = 'Tappa'
        AND e.entryable_id = m.old_id::text
    SQL

    # 6. Aggiorna closures per Tappa (se ce ne sono ancora con closeable_type)
    # closeable_id è VARCHAR, quindi possiamo usare ::text
    execute <<-SQL
      UPDATE closures c
      SET closeable_id = m.new_uuid::text
      FROM tappe_id_map m
      WHERE c.closeable_type = 'Tappa'
        AND c.closeable_id = m.old_id::text
    SQL

    # Nota: goldnesses e not_nows sono già consolidate su entry_id
    # e non hanno più record con goldenable_type/not_nowable_type = 'Tappa'

    # 7. Drop vecchie colonne e indici
    remove_index :tappa_giri, :tappa_id, if_exists: true
    remove_column :tappa_giri, :tappa_id

    # 8. Cambia primary key di tappe da bigint a uuid
    execute "ALTER TABLE tappe DROP CONSTRAINT tappe_pkey"
    remove_column :tappe, :id
    rename_column :tappe, :uuid, :id
    execute "ALTER TABLE tappe ADD PRIMARY KEY (id)"

    # 9. Rinomina la colonna uuid in tappa_giri
    rename_column :tappa_giri, :tappa_uuid, :tappa_id

    # 10. Ricrea indici
    add_index :tappa_giri, :tappa_id

    # 11. Drop la tabella temporanea
    execute "DROP TABLE IF EXISTS tappe_id_map"

    say "Conversione tappe a UUID completata"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot convert UUID back to bigint"
  end
end
