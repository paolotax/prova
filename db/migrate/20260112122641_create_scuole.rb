class CreateScuole < ActiveRecord::Migration[8.0]
  def change
    create_table :scuole, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :import_scuola, foreign_key: true

      # Campi copiati da ImportScuola
      t.string :codice_ministeriale
      t.string :denominazione
      t.string :indirizzo
      t.string :cap
      t.string :comune
      t.string :provincia
      t.string :regione
      t.string :tipo_scuola
      t.string :email
      t.string :pec
      t.string :telefono

      # Campi tenant-specific
      t.text :note
      t.integer :priorita, default: 0
      t.string :stato, default: 'attiva'

      t.timestamps
    end

    add_index :scuole, [:account_id, :codice_ministeriale], unique: true
    add_index :scuole, [:account_id, :denominazione]
  end
end
