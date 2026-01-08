class AddPasswordlessEnabledToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :passwordless_enabled, :boolean, default: false, null: false
  end
end
