class RecreateAdozioni < ActiveRecord::Migration[8.0]
  def change
    create_table :adozioni, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :classe, type: :uuid, null: false, foreign_key: true
      t.references :libro, foreign_key: true
      t.references :import_adozione, foreign_key: true

      # Campi copiati da ImportAdozione
      t.string :codice_isbn
      t.string :titolo
      t.string :editore
      t.string :autori
      t.string :disciplina
      t.integer :prezzo_cents, default: 0

      # Flags da ImportAdozione
      t.boolean :nuova_adozione, default: false
      t.boolean :da_acquistare, default: false
      t.boolean :consigliato, default: false

      # Campi tenant-specific per gestione ordini
      t.integer :numero_copie, default: 0
      t.text :note

      t.timestamps
    end

    add_index :adozioni, [:classe_id, :codice_isbn], unique: true
    add_index :adozioni, [:account_id, :libro_id]
  end
end
