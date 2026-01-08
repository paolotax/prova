class MakeAccountIdRequiredOnAppunti < ActiveRecord::Migration[8.0]
  def change
    # account_id remains optional for existing data
    add_index :appunti, [:account_id, :created_at], if_not_exists: true
  end
end
