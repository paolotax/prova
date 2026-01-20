# frozen_string_literal: true

class CreateEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :entries, id: :uuid do |t|
      # Delegated Type - using string for entryable_id to support both UUID (Appunto) and bigint (Documento, Tappa)
      t.string :entryable_type, null: false
      t.string :entryable_id, null: false

      # Triage
      t.references :column, type: :uuid, foreign_key: true

      # Raggruppamento (giri uses bigint, not uuid)
      t.bigint :giro_id
      t.index :giro_id

      # Multi-tenancy
      t.bigint :user_id, null: false
      t.references :account, type: :uuid, foreign_key: true, null: false

      t.timestamps
    end

    add_index :entries, [:entryable_type, :entryable_id], unique: true
    add_index :entries, [:account_id, :entryable_type]
    add_index :entries, :user_id

    add_foreign_key :entries, :users
    add_foreign_key :entries, :giri
  end
end
