class AddIndexToImportScuoleCodicescuola < ActiveRecord::Migration[7.1]
  def change
    add_index :import_scuole, :CODICESCUOLA, name: "index_import_scuole_on_CODICESCUOLA", unique: true
  end
end
