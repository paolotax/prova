class AddSlugToLibri < ActiveRecord::Migration[7.1]
  def change
    add_column :libri, :slug, :string
    add_index :libri, :slug, unique: true
  end
end
