class AddFieldsToStats < ActiveRecord::Migration[8.0]
  def change
    add_column :stats, :titolo, :string
    add_column :stats, :categoria, :string
    add_column :stats, :anno, :string
  end
end
