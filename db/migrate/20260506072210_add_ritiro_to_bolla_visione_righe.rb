class AddRitiroToBollaVisioneRighe < ActiveRecord::Migration[8.1]
  def change
    add_column :bolla_visione_righe, :esito, :integer
    add_column :bolla_visione_righe, :processato_at, :datetime
    add_reference :bolla_visione_righe, :documento_riga, foreign_key: true
    add_index :bolla_visione_righe, [:bolla_visione_id, :esito]
    add_index :bolla_visione_righe, :processato_at
  end
end
