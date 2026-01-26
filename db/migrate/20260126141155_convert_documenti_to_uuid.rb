class ConvertDocumentiToUuid < ActiveRecord::Migration[8.1]
  def up
    # 1. Drop la view che dipende da documenti
    execute "DROP VIEW IF EXISTS view_giacenze CASCADE"

    # 2. Drop foreign keys
    remove_foreign_key :documenti, column: :documento_padre_id, if_exists: true

    # 3. Aggiungi colonne UUID temporanee
    add_column :documenti, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false
    add_column :documenti, :documento_padre_uuid, :uuid
    add_column :documento_righe, :documento_uuid, :uuid

    # 4. Crea mapping table temporanea per old_id -> new_uuid
    execute <<-SQL
      CREATE TEMPORARY TABLE documenti_id_map AS
      SELECT id AS old_id, uuid AS new_uuid FROM documenti
    SQL

    # 5. Popola documento_padre_uuid usando il mapping
    execute <<-SQL
      UPDATE documenti d
      SET documento_padre_uuid = m.new_uuid
      FROM documenti_id_map m
      WHERE d.documento_padre_id = m.old_id
    SQL

    # 6. Popola documento_uuid in documento_righe
    execute <<-SQL
      UPDATE documento_righe dr
      SET documento_uuid = m.new_uuid
      FROM documenti_id_map m
      WHERE dr.documento_id = m.old_id
    SQL

    # 7. Drop vecchie colonne e indici
    remove_index :documenti, :documento_padre_id, if_exists: true
    remove_index :documento_righe, :documento_id, if_exists: true
    remove_index :documento_righe, [:documento_id, :riga_id], if_exists: true

    remove_column :documenti, :documento_padre_id
    remove_column :documento_righe, :documento_id

    # 8. Cambia primary key di documenti da bigint a uuid
    execute "ALTER TABLE documenti DROP CONSTRAINT documenti_pkey"
    remove_column :documenti, :id
    rename_column :documenti, :uuid, :id
    execute "ALTER TABLE documenti ADD PRIMARY KEY (id)"

    # 9. Rinomina le colonne uuid
    rename_column :documenti, :documento_padre_uuid, :documento_padre_id
    rename_column :documento_righe, :documento_uuid, :documento_id

    # 10. Ricrea indici
    add_index :documenti, :documento_padre_id
    add_index :documento_righe, :documento_id
    add_index :documento_righe, [:documento_id, :riga_id], unique: true

    # 11. Ricrea foreign key (self-reference)
    add_foreign_key :documenti, :documenti, column: :documento_padre_id

    # 12. Ricrea la view view_giacenze
    execute <<-SQL
      CREATE VIEW view_giacenze AS
      SELECT users.id as user_id, libri.id as libro_id, libri.titolo, libri.codice_isbn,
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and (documenti.status = 0)), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and (documenti.status = 0)), 0)) as ordini,

          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento <> 2 and documenti.status <> 0), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento <> 2 and documenti.status <> 0), 0)) as vendite,

          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 2), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 2), 0)) as carichi

      FROM righe
      INNER JOIN libri ON righe.libro_id = libri.id
      INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
      INNER JOIN documenti ON documento_righe.documento_id = documenti.id
      INNER JOIN causali ON documenti.causale_id = causali.id
      INNER JOIN users ON users.id = documenti.user_id
      GROUP BY 1, 2, 3, 4
      ORDER BY 3
    SQL

    # 13. Drop la tabella temporanea
    execute "DROP TABLE IF EXISTS documenti_id_map"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Cannot convert UUID back to bigint"
  end
end
