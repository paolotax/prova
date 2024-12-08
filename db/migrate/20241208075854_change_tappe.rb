class ChangeTappe < ActiveRecord::Migration[7.2]
  def change
    change_column :tappe, :data_tappa, :date
    change_column :tappe, :position, :integer, null: false
    remove_column :tappe, :ordine

    #add_index :tappe, [:user_id, :data_tappa, :position], unique: true
  end
end
