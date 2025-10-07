class CreateSconti < ActiveRecord::Migration[8.0]
  def change
    create_table :sconti do |t|
      # Polymorphic association - può essere Cliente, Editore, o nil per sconti globali
      t.references :scontabile, polymorphic: true, index: true

      # Se nil, lo sconto vale per tutte le categorie
      t.references :categoria, foreign_key: true

      t.decimal :percentuale_sconto, precision: 5, scale: 2, null: false
      t.date :data_inizio, null: false
      t.date :data_fine

      # Tipo di sconto: 'vendita' o 'acquisto'
      t.integer :tipo_sconto, null: false, default: 0

      t.timestamps
    end

    # Indice per garantire unicità: stessa entità + categoria + data_inizio + tipo
    add_index :sconti,
              [:scontabile_type, :scontabile_id, :categoria_id, :data_inizio, :tipo_sconto],
              unique: true,
              name: 'index_sconti_unique'
  end
end
