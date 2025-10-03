class CreateAdozioniComunicate < ActiveRecord::Migration[8.0]
  def change
    create_table :adozioni_comunicate do |t|
      # Campi dal file Excel dell'editore
      t.string :cod_agente
      t.string :anno_scolastico
      t.string :cod_ministeriale
      t.string :descrizione_scuola
      t.string :indirizzo
      t.string :cap
      t.string :comune
      t.string :provincia
      t.string :cod_scuola
      t.string :editore
      t.string :ean
      t.string :titolo
      t.string :classe
      t.string :sezione
      t.integer :alunni
      
      # Campi per il confronto con import_adozioni
      t.string :codice_scuola_match
      t.string :codice_isbn_match
      t.string :anno_corso_match
      t.string :sezione_anno_match
      
      # Riferimenti
      t.bigint :user_id, null: false
      t.bigint :import_adozione_id
      
      t.timestamps
    end
    
    add_index :adozioni_comunicate, :user_id
    add_index :adozioni_comunicate, :import_adozione_id
    add_index :adozioni_comunicate, :ean
    add_index :adozioni_comunicate, :cod_ministeriale
    add_index :adozioni_comunicate, [:user_id, :ean]
    add_index :adozioni_comunicate, [:user_id, :cod_ministeriale]
    
    add_foreign_key :adozioni_comunicate, :users
    add_foreign_key :adozioni_comunicate, :import_adozioni
  end
end
