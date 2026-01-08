class MakeAccountIdRequiredOnAppunti < ActiveRecord::Migration[8.0]
  def change
    change_column_null :appunti, :account_id, false
    add_index :appunti, [:account_id, :created_at]
  end
end
