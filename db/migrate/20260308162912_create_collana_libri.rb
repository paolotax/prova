class CreateCollanaLibri < ActiveRecord::Migration[8.1]
  def change
    create_table :collana_libri, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :collana, null: false, type: :uuid, index: true
      t.references :libro, null: false, type: :bigint, index: true

      t.string :classi_target
      t.integer :position

      t.timestamps
    end

    add_index :collana_libri, [:collana_id, :libro_id], unique: true
  end
end
