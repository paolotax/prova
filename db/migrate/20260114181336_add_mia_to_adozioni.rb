class AddMiaToAdozioni < ActiveRecord::Migration[8.0]
  def change
    add_column :adozioni, :mia, :boolean, default: false, null: false
    add_index :adozioni, [:account_id, :mia]
  end
end
