class AddNumeroToAppunti < ActiveRecord::Migration[8.0]
  def change
    add_column :appunti, :numero, :integer
    add_index :appunti, [:account_id, :numero, :created_at]
  end
end
