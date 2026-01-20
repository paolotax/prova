# frozen_string_literal: true

class AddEntryIdToStateRecords < ActiveRecord::Migration[8.0]
  def change
    # Add entry_id to goldnesses
    add_column :goldnesses, :entry_id, :uuid
    add_index :goldnesses, :entry_id, unique: true
    add_foreign_key :goldnesses, :entries

    # Add entry_id to closures
    add_column :closures, :entry_id, :uuid
    add_index :closures, :entry_id, unique: true
    add_foreign_key :closures, :entries

    # Add entry_id to not_nows
    add_column :not_nows, :entry_id, :uuid
    add_index :not_nows, :entry_id, unique: true
    add_foreign_key :not_nows, :entries
  end
end
