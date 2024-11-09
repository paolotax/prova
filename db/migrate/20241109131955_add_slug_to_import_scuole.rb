class AddSlugToImportScuole < ActiveRecord::Migration[7.1]
  def change
    add_column :import_scuole, :slug, :string
    add_index :import_scuole, :slug, unique: true
  end
end
