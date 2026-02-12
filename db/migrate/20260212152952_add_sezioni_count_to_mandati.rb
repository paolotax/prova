class AddSezioniCountToMandati < ActiveRecord::Migration[8.1]
  def change
    add_column :mandati, :sezioni_count, :integer, default: 0
  end
end
