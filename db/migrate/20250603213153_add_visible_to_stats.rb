class AddVisibleToStats < ActiveRecord::Migration[8.0]
  def change
    add_column :stats, :visible, :boolean, default: true, null: false
  end
end
