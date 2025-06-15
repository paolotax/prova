class AddPositionToStats < ActiveRecord::Migration[8.0]
  def change
    add_column :stats, :position, :integer
  end
end
