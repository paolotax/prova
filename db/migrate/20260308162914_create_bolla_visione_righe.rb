class CreateBollaVisioneRighe < ActiveRecord::Migration[8.1]
  def change
    create_table :bolla_visione_righe, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :bolla_visione, null: false, type: :uuid, index: true
      t.references :libro, null: false, type: :bigint, index: true

      t.integer :quantita, null: false, default: 1
      t.string :classi_target
      t.integer :position

      t.timestamps
    end
  end
end
