class CreateMagicLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_links, id: :uuid do |t|
      t.references :user, null: false, type: :bigint, index: true
      t.string :token, null: false
      t.string :purpose, null: false, default: "sign_in"
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.string :ip_address

      t.timestamps
    end

    add_index :magic_links, :token, unique: true
    add_index :magic_links, [:user_id, :purpose]
    add_index :magic_links, :expires_at
  end
end
