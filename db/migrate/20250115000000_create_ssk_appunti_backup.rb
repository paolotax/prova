class CreateSskAppuntiBackup < ActiveRecord::Migration[8.0]
  def change
    create_table :ssk_appunti_backup do |t|
      # Dati originali dell'appunto
      t.bigint :original_appunto_id, null: false
      t.bigint :user_id, null: false
      t.string :nome # saggio, seguito, kit
      t.text :body
      t.string :email
      t.string :telefono
      t.string :stato
      t.string :team
      t.boolean :active
      t.datetime :completed_at
      t.datetime :original_created_at
      t.datetime :original_updated_at
      
      # Dati della scuola (denormalizzati per preservare i dati)
      t.bigint :import_scuola_id
      t.string :codice_scuola
      t.string :denominazione_scuola
      t.string :descrizione_comune
      t.string :descrizione_caratteristica_scuola
      t.string :descrizione_tipologia_grado_istruzione_scuola
      t.string :codice_istituto_riferimento
      t.string :denominazione_istituto_riferimento
      t.string :area_geografica
      t.string :regione
      t.string :provincia
      
      # Dati dell'adozione/libro (denormalizzati per preservare i dati)
      t.bigint :import_adozione_id
      t.string :codice_isbn
      t.string :autori
      t.string :titolo
      t.string :sottotitolo
      t.string :volume
      t.string :editore
      t.string :prezzo
      t.string :disciplina
      t.string :nuova_adozione
      t.string :da_acquistare
      t.string :consigliato
      
      # Dati della classe (denormalizzati)
      t.bigint :classe_id
      t.string :anno_corso
      t.string :sezione_anno
      t.string :combinazione
      t.string :tipo_grado_scuola
      
      # Dati del libro dell'utente (se presente)
      t.bigint :libro_id
      t.string :libro_titolo
      t.string :libro_categoria
      t.string :libro_disciplina
      t.integer :libro_prezzo_cents
      t.text :libro_note
      
      # Anno scolastico di backup
      t.string :anno_scolastico_backup
      
      # Timestamp del backup
      t.datetime :backup_created_at, default: -> { 'CURRENT_TIMESTAMP' }
      
      t.timestamps
    end
    
    # Indici per facilitare ricerche
    add_index :ssk_appunti_backup, :original_appunto_id
    add_index :ssk_appunti_backup, :user_id
    add_index :ssk_appunti_backup, :nome
    add_index :ssk_appunti_backup, :anno_scolastico_backup
    add_index :ssk_appunti_backup, :codice_scuola
    add_index :ssk_appunti_backup, :codice_isbn
    add_index :ssk_appunti_backup, [:user_id, :anno_scolastico_backup]
    add_index :ssk_appunti_backup, [:codice_scuola, :anno_corso, :sezione_anno]
  end
end
