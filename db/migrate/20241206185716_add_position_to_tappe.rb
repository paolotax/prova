class AddPositionToTappe < ActiveRecord::Migration[7.2]
  def change
    add_column :tappe, :position, :integer
  end
end
