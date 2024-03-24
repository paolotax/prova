class CreateViewAdozioniElementari < ActiveRecord::Migration[7.1]
  def change
    create_view :view_adozioni_elementari, materialized: :true

    add_index :view_adozioni_elementari, [:provincia, :classe, :disciplina, :titolo]
    add_index :view_adozioni_elementari, :isbn
    add_index :view_adozioni_elementari, :provincia    
  end
end
