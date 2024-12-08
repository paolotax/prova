class AddIndexToTappe2 < ActiveRecord::Migration[7.2]
  def change
    add_index :tappe, [:user_id, :data_tappa, :position], unique: true
  end
end
