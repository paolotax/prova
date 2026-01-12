class CreateClassi < ActiveRecord::Migration[8.0]
  def change
    create_table :classi, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :scuola, type: :uuid, null: false, foreign_key: true

      # Dati classe
      t.string :anno_corso  # 1, 2, 3, 4, 5
      t.string :sezione     # A, B, C...
      t.string :combinazione
      t.string :tipo_scuola

      # Riferimento a Views::Classe originale (composite key)
      t.string :codice_ministeriale_origine
      t.string :classe_origine
      t.string :sezione_origine
      t.string :combinazione_origine

      # Campi tenant-specific
      t.text :note
      t.integer :numero_alunni

      t.timestamps
    end

    add_index :classi, [:scuola_id, :anno_corso, :sezione], unique: true
    add_index :classi, [:account_id, :codice_ministeriale_origine, :classe_origine, :sezione_origine],
              name: 'index_classi_on_origine'
  end
end
