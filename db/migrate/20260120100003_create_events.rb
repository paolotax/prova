# frozen_string_literal: true

class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events, id: :uuid do |t|
      t.references :entry, type: :uuid, foreign_key: true, null: false
      t.bigint :user_id
      t.references :account, type: :uuid, foreign_key: true, null: false
      t.string :action, null: false
      t.jsonb :particulars, default: {}

      t.timestamps
    end

    add_index :events, [:entry_id, :created_at]
    add_index :events, [:account_id, :action]
    add_index :events, :user_id

    add_foreign_key :events, :users
  end
end
