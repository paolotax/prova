class AddDaAcquistareToAdozioniComunicate < ActiveRecord::Migration[7.0]
  def change
    add_column :adozioni_comunicate, :da_acquistare, :string
  end
end
