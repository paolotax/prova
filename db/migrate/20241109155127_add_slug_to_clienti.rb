class AddSlugToClienti < ActiveRecord::Migration[7.1]
  def change
    add_column :clienti, :slug, :string
    add_index :clienti, :slug, unique: true
  end
end
