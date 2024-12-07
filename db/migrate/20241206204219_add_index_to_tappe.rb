class AddIndexToTappe < ActiveRecord::Migration[7.2]
  def change
    #add_index :tappe, [:data_tappa, :position], unique: true
  end
end
