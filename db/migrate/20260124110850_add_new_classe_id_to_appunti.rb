class AddNewClasseIdToAppunti < ActiveRecord::Migration[8.1]
  def up
    # Step 1: Aggiungi colonna UUID per nuova classe_id
    add_column :appunti, :new_classe_id, :uuid
    add_index :appunti, :new_classe_id

    # Step 2: Crea le Classi mancanti da Views::Classe
    execute <<-SQL
      INSERT INTO classi (id, account_id, scuola_id, anno_corso, sezione, combinazione, tipo_scuola,
                          codice_ministeriale_origine, classe_origine, sezione_origine, combinazione_origine,
                          created_at, updated_at)
      SELECT
        gen_random_uuid(),
        a.account_id,
        s.id,
        vc.classe,
        vc.sezione,
        vc.combinazione,
        isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
        vc.codice_ministeriale,
        vc.classe,
        vc.sezione,
        vc.combinazione,
        NOW(),
        NOW()
      FROM appunti a
      JOIN view_classi vc ON vc.id = a.classe_id
      JOIN scuole s ON s.codice_ministeriale = vc.codice_ministeriale AND s.account_id = a.account_id
      LEFT JOIN import_scuole isc ON isc."CODICESCUOLA" = vc.codice_ministeriale
      WHERE a.classe_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM classi c
          WHERE c.account_id = a.account_id
            AND c.scuola_id = s.id
            AND c.anno_corso = vc.classe
            AND c.sezione = vc.sezione
        )
      GROUP BY a.account_id, s.id, vc.classe, vc.sezione, vc.combinazione,
               vc.codice_ministeriale, isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"
    SQL

    # Step 3: Aggiorna appunti con la nuova classe_id
    execute <<-SQL
      UPDATE appunti
      SET new_classe_id = c.id
      FROM view_classi vc, scuole s, classi c
      WHERE vc.id = appunti.classe_id
        AND s.codice_ministeriale = vc.codice_ministeriale
        AND s.account_id = appunti.account_id
        AND c.scuola_id = s.id
        AND c.anno_corso = vc.classe
        AND c.sezione = vc.sezione
        AND c.account_id = appunti.account_id
        AND appunti.classe_id IS NOT NULL
    SQL

    # Step 4: Rimuovi vecchia colonna e rinomina
    remove_column :appunti, :classe_id
    rename_column :appunti, :new_classe_id, :classe_id

    # Step 5: Aggiungi foreign key
    add_foreign_key :appunti, :classi, column: :classe_id
  end

  def down
    remove_foreign_key :appunti, column: :classe_id

    # Ricrea colonna bigint
    rename_column :appunti, :classe_id, :new_classe_id
    add_column :appunti, :classe_id, :bigint
    add_index :appunti, :classe_id

    # Backfill da Classe a Views::Classe
    execute <<-SQL
      UPDATE appunti a
      SET classe_id = vc.id
      FROM classi c
      JOIN view_classi vc ON vc.codice_ministeriale = c.codice_ministeriale_origine
                         AND vc.classe = c.classe_origine
                         AND vc.sezione = c.sezione_origine
      WHERE c.id = a.new_classe_id
        AND a.new_classe_id IS NOT NULL
    SQL

    remove_column :appunti, :new_classe_id
  end
end
