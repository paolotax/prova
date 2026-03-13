class CreateScartate < ActiveRecord::Migration[8.1]
  def change
    create_table :scartate, id: :uuid do |t|
      t.references :scuola, type: :uuid, null: false
      t.references :user, null: false
      t.references :account, type: :uuid, null: false
      t.timestamps
    end
    add_index :scartate, [:scuola_id, :user_id], unique: true
  end
end
