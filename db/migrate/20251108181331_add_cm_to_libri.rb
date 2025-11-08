class AddCmToLibri < ActiveRecord::Migration[8.0]
  def change
    add_column :libri, :cm, :string
    add_index :libri, :cm
  end
end
