class AddIndexProvinciaToImportScuole < ActiveRecord::Migration[7.1]
  def change
    add_index :import_scuole, :PROVINCIA  
    add_index :import_scuole, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA 
  end
end
