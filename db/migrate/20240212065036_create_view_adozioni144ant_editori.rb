class CreateViewAdozioni144antEditori < ActiveRecord::Migration[7.1]
  def change
    create_view :view_adozioni144ant_editori, materialized: :true

    add_index :view_adozioni144ant_editori, [:provincia, :editore], unique: true
    add_index :view_adozioni144ant_editori, :editore
    
  end
end
