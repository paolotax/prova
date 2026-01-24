class ConvertClientiToUuidAndMigrateImportScuola < ActiveRecord::Migration[8.0]
  def up
    # ========================================
    # STEP 1: Aggiungi colonna uuid a clienti
    # ========================================
    add_column :clienti, :uuid, :uuid, default: -> { "gen_random_uuid()" }, null: false

    # ========================================
    # STEP 2: Aggiungi colonne uuid temporanee alle tabelle con FK polimorfiche
    # ========================================
    add_column :documenti, :clientable_uuid, :uuid
    add_column :sconti, :scontabile_uuid, :uuid
    add_column :tappe, :tappable_uuid, :uuid

    # ========================================
    # STEP 3: Popola uuid per record Cliente
    # ========================================

    # documenti: Cliente -> clienti.uuid
    execute <<-SQL
      UPDATE documenti
      SET clientable_uuid = clienti.uuid
      FROM clienti
      WHERE documenti.clientable_id = clienti.id
        AND documenti.clientable_type = 'Cliente';
    SQL

    # sconti: Cliente -> clienti.uuid
    execute <<-SQL
      UPDATE sconti
      SET scontabile_uuid = clienti.uuid
      FROM clienti
      WHERE sconti.scontabile_id = clienti.id
        AND sconti.scontabile_type = 'Cliente';
    SQL

    # tappe: Cliente -> clienti.uuid
    execute <<-SQL
      UPDATE tappe
      SET tappable_uuid = clienti.uuid
      FROM clienti
      WHERE tappe.tappable_id = clienti.id
        AND tappe.tappable_type = 'Cliente';
    SQL

    # ========================================
    # STEP 4: Converti ImportScuola -> Scuola
    # ========================================

    # documenti: ImportScuola -> Scuola (tramite scuole.import_scuola_id)
    execute <<-SQL
      UPDATE documenti
      SET clientable_uuid = scuole.id,
          clientable_type = 'Scuola'
      FROM scuole
      WHERE documenti.clientable_id = scuole.import_scuola_id
        AND documenti.clientable_type = 'ImportScuola';
    SQL

    # sconti: ImportScuola -> Scuola
    execute <<-SQL
      UPDATE sconti
      SET scontabile_uuid = scuole.id,
          scontabile_type = 'Scuola'
      FROM scuole
      WHERE sconti.scontabile_id = scuole.import_scuola_id
        AND sconti.scontabile_type = 'ImportScuola';
    SQL

    # tappe: ImportScuola -> Scuola
    execute <<-SQL
      UPDATE tappe
      SET tappable_uuid = scuole.id,
          tappable_type = 'Scuola'
      FROM scuole
      WHERE tappe.tappable_id = scuole.import_scuola_id
        AND tappe.tappable_type = 'ImportScuola';
    SQL

    # ========================================
    # STEP 5: Gestisci record orfani (ImportScuola senza Scuola corrispondente)
    # ========================================

    # Imposta a NULL i record orfani
    execute <<-SQL
      UPDATE documenti
      SET clientable_uuid = NULL, clientable_type = NULL
      WHERE clientable_type = 'ImportScuola'
        AND clientable_uuid IS NULL;
    SQL

    execute <<-SQL
      UPDATE sconti
      SET scontabile_uuid = NULL, scontabile_type = NULL
      WHERE scontabile_type = 'ImportScuola'
        AND scontabile_uuid IS NULL;
    SQL

    # ========================================
    # STEP 6: Aggiorna appunti.appuntabile_id per Cliente
    # ========================================

    # appunti.appuntabile_id è già uuid, aggiorna con il nuovo uuid del cliente
    execute <<-SQL
      UPDATE appunti
      SET appuntabile_id = clienti.uuid
      FROM clienti
      WHERE appunti.appuntabile_type = 'Cliente'
        AND appunti.appuntabile_id IS NULL;
    SQL

    # ========================================
    # STEP 7: Rimuovi vecchi indici
    # ========================================

    remove_index :documenti, name: :index_documenti_on_clientable_type_and_clientable_id, if_exists: true
    remove_index :sconti, name: :index_sconti_on_scontabile, if_exists: true
    remove_index :sconti, name: :index_sconti_unique, if_exists: true
    remove_index :tappe, name: :index_tappe_on_tappable, if_exists: true

    # ========================================
    # STEP 8: Rimuovi vecchie colonne e rinomina nuove
    # ========================================

    remove_column :documenti, :clientable_id
    rename_column :documenti, :clientable_uuid, :clientable_id

    remove_column :sconti, :scontabile_id
    rename_column :sconti, :scontabile_uuid, :scontabile_id

    remove_column :tappe, :tappable_id
    rename_column :tappe, :tappable_uuid, :tappable_id

    # ========================================
    # STEP 9: Ricrea indici con nuove colonne uuid
    # ========================================

    add_index :documenti, [:clientable_type, :clientable_id], name: :index_documenti_on_clientable
    add_index :sconti, [:scontabile_type, :scontabile_id], name: :index_sconti_on_scontabile
    add_index :sconti, [:user_id, :scontabile_type, :scontabile_id, :categoria_id, :data_inizio, :tipo_sconto],
              name: :index_sconti_unique, unique: true
    add_index :tappe, [:tappable_type, :tappable_id], name: :index_tappe_on_tappable

    # ========================================
    # STEP 10: Cambia primary key di clienti da bigint a uuid
    # ========================================

    execute <<-SQL
      ALTER TABLE clienti DROP CONSTRAINT clienti_pkey;
    SQL

    remove_column :clienti, :id
    rename_column :clienti, :uuid, :id

    execute <<-SQL
      ALTER TABLE clienti ADD PRIMARY KEY (id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, <<~MSG
      Questa migrazione non è reversibile perché:
      1. I record ImportScuola sono stati convertiti in Scuola
      2. Gli ID interi originali dei clienti sono stati persi
      3. Le relazioni polimorfiche sono state modificate

      Per rollback, ripristinare da backup del database.
    MSG
  end
end
