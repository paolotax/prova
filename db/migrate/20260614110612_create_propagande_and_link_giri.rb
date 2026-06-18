class CreatePropagandeAndLinkGiri < ActiveRecord::Migration[8.1]
  def change
    create_table :propagande, id: :uuid do |t|
      t.string :nome, null: false
      t.uuid :account_id, null: false
      t.bigint :user_id, null: false
      t.timestamps
    end
    add_index :propagande, :account_id
    add_index :propagande, :user_id

    add_column :giri, :propaganda_id, :uuid
    add_index :giri, :propaganda_id
  end
end
