class UpdateViewClassiToVersion2 < ActiveRecord::Migration[7.1]
  def change

    drop_view :view_classi, materialized: true, revert_to_version: 1  
  
    create_view :view_classi, version: 2, materialized: :true

    add_index :view_classi, [:codice_ministeriale, :classe, :sezione, :combinazione], unique: true
    add_index :view_classi, :codice_ministeriale
    add_index :view_classi, :provincia    
  end
end
