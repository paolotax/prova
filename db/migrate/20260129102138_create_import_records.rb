class CreateImportRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :import_records, id: :uuid do |t|
      t.references :user, null: false, foreign_key: false, type: :bigint
      t.references :account, null: false, foreign_key: false, type: :uuid
      t.integer :import_type, null: false
      t.integer :status, default: 0, null: false
      t.integer :imported_count, default: 0
      t.integer :updated_count, default: 0
      t.integer :errors_count, default: 0
      t.text :error_messages, array: true, default: []
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :import_records, [:account_id, :created_at]
    add_index :import_records, [:user_id, :import_type]
  end
end
