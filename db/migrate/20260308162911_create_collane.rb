class CreateCollane < ActiveRecord::Migration[8.1]
  def change
    create_table :collane, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :user, null: false, type: :bigint, index: true

      t.string :nome, null: false

      t.timestamps
    end
  end
end
