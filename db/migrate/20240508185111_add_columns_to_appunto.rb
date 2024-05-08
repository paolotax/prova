class AddColumnsToAppunto < ActiveRecord::Migration[7.1]
  def change
    add_column :appunti, :completed_at, :datetime
    add_column :appunti, :team, :string
    add_reference :appunti, :classe
  end
end
