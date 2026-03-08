class CreateBolleVisione < ActiveRecord::Migration[8.1]
  def change
    create_table :bolle_visione, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :user, null: false, type: :bigint, index: true

      t.integer :numero, null: false
      t.date :data_bolla, null: false
      t.references :collana, null: false, type: :uuid, index: true
      t.references :scuola, null: false, type: :uuid, index: true
      t.references :tappa, null: true, type: :uuid, index: true
      t.references :referente, null: true, type: :uuid, index: true
      t.text :note

      t.timestamps
    end

    add_index :bolle_visione, [:account_id, :numero], unique: true
  end
end
