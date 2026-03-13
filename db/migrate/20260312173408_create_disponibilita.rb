class CreateDisponibilita < ActiveRecord::Migration[8.1]
  def change
    create_table :disponibilita, id: :uuid do |t|
      t.references :scuola, type: :uuid, null: false
      t.references :account, type: :uuid, null: false
      t.references :user, null: true
      t.string :tipo, null: false
      t.integer :giorno_settimana
      t.date :data
      t.time :ora_inizio
      t.time :ora_fine
      t.string :titolo
      t.boolean :ricorrente, default: false
      t.timestamps
    end

    add_index :disponibilita, [:scuola_id, :tipo]
    add_index :disponibilita, [:scuola_id, :tipo, :giorno_settimana],
              name: "idx_disponibilita_scuola_tipo_giorno"
  end
end
