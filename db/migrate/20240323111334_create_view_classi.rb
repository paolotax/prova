class CreateViewClassi < ActiveRecord::Migration[7.1]
  def change
    create_view :view_classi, materialized: :true

    add_index :view_classi, [:codice_ministeriale, :classe, :sezione, :combinazione], unique: true
    add_index :view_classi, :codice_ministeriale
    add_index :view_classi, :provincia    
  end
end
