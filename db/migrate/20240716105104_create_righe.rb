class CreateRighe < ActiveRecord::Migration[7.1]
  def change
    
    create_table :righe do |t|

      t.references :libro,           null: false, foreign_key: true
      t.integer :quantita,           default: 1
      t.integer :prezzo_copertina_cents, default: 0
      t.integer :prezzo_cents,       default: 0 
      t.decimal :sconto,             precision: 5, scale: 2, default: 0.0
      t.integer :iva_cents,          default: 0
      t.integer :status

      t.timestamps
    end

    create_table :documento_righe do |t|
      
      t.belongs_to :documento
      t.belongs_to :riga
      t.integer :posizione

      t.timestamps
    end

    add_index :documento_righe, [:documento_id, :riga_id], unique: true

  end
end
