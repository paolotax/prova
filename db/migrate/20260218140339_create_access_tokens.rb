class CreateAccessTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :access_tokens, id: :uuid do |t|
      t.uuid :membership_id, null: false
      t.string :token
      t.string :description
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :access_tokens, :membership_id
    add_index :access_tokens, :token, unique: true
  end
end
