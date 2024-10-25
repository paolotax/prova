class AddConfezioniCountToConfezione < ActiveRecord::Migration[7.1]
  def change
    add_column :libri, :confezioni_count, :integer, null: false, default: 0
  end
end
