class CreateAppuntoRighe < ActiveRecord::Migration[8.0]
  def change
    create_table :appunto_righe, id: :uuid do |t|
      t.references :appunto, null: false, foreign_key: true
      t.references :riga, null: false, foreign_key: true
      t.integer :posizione, default: 0

      t.timestamps
    end

    add_index :appunto_righe, [:appunto_id, :posizione]
    add_index :appunto_righe, [:appunto_id, :riga_id], unique: true
  end
end
