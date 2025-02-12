class AddPositionToUserScuole < ActiveRecord::Migration[7.2]
  def change
    add_column :user_scuole, :position, :integer
    add_index :user_scuole, [:user_id, :position]
  end
end
