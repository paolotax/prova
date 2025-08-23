class UpdateViewClassiToVersion3 < ActiveRecord::Migration[8.0]
  def change
     drop_view :view_classi, materialized: true, revert_to_version: 2
  
    create_view :view_classi, version: 3, materialized: :true

    add_index :view_classi, [:codice_ministeriale, :classe, :sezione, :combinazione], unique: true
    add_index :view_classi, :codice_ministeriale
    add_index :view_classi, :provincia    
 
  end
end
