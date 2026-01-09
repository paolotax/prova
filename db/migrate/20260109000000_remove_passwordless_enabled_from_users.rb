class RemovePasswordlessEnabledFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :passwordless_enabled, :boolean, default: false, null: false
  end
end
