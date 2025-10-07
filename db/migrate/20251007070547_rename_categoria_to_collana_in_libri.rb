class RenameCategoriaToCollanaInLibri < ActiveRecord::Migration[8.0]
  def change
    rename_column :libri, :categoria, :collana
  end
end
