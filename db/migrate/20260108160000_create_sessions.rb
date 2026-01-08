class CreateSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :user, null: false, type: :bigint, index: true
      t.references :account, null: true, type: :uuid, index: true
      t.string :token, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_active_at

      t.timestamps
    end

    add_index :sessions, :token, unique: true
    add_index :sessions, [:user_id, :last_active_at]
  end
end
