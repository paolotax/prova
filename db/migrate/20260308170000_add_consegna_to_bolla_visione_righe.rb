class AddConsegnaToBollaVisioneRighe < ActiveRecord::Migration[8.0]
  def change
    add_column :bolla_visione_righe, :consegna, :jsonb, default: {}
  end
end
