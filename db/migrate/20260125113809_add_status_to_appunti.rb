class AddStatusToAppunti < ActiveRecord::Migration[8.0]
  def up
    add_column :appunti, :status, :string, default: "drafted", null: false
    add_index :appunti, [:account_id, :status]

    # Backfill: tutti gli appunti esistenti sono published
    execute "UPDATE appunti SET status = 'published'"
  end

  def down
    remove_index :appunti, [:account_id, :status]
    remove_column :appunti, :status
  end
end
