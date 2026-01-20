# frozen_string_literal: true

class CreateColumns < ActiveRecord::Migration[8.0]
  def change
    create_table :columns, id: :uuid do |t|
      t.string :name, null: false
      t.string :color, default: "#6366f1"
      t.integer :position, default: 0
      t.references :account, type: :uuid, foreign_key: true, null: false

      t.timestamps
    end

    add_index :columns, [:account_id, :position]
    add_index :columns, [:account_id, :name], unique: true
  end
end
