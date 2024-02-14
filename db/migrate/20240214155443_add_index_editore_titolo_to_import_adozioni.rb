class AddIndexEditoreTitoloToImportAdozioni < ActiveRecord::Migration[7.1]
  def change
    add_index :import_adozioni, :TITOLO  
    add_index :import_adozioni, :DISCIPLINA  
    add_index :import_adozioni, :EDITORE  
  end
end
