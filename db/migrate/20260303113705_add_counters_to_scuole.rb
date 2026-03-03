class AddCountersToScuole < ActiveRecord::Migration[8.1]
  def change
    add_column :scuole, :classi_count, :integer, default: 0, null: false
    add_column :scuole, :adozioni_count, :integer, default: 0, null: false
    add_column :scuole, :mie_adozioni_count, :integer, default: 0, null: false
  end
end
