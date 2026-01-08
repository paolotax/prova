class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships, id: :uuid do |t|
      t.references :user, null: false, type: :bigint, index: true
      t.references :account, null: false, type: :uuid, index: true
      t.integer :role, null: false, default: 0

      t.timestamps
    end

    add_index :memberships, [:user_id, :account_id], unique: true
  end
end
