class AddActiveToAppunti < ActiveRecord::Migration[7.2]
  def change
    add_column :appunti, :active, :boolean
  end
end
