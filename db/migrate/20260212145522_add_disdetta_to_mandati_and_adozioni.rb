class AddDisdettaToMandatiAndAdozioni < ActiveRecord::Migration[8.1]
  def change
    add_column :mandati, :disdetta, :boolean, default: false, null: false
    add_column :adozioni, :disdetta, :boolean, default: false, null: false
  end
end
