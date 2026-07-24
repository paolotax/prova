class AddRiportataToAdozioni < ActiveRecord::Migration[8.1]
  # Riga creata dalla promozione cieca (riporto/prosegui), non confermata dal MIUR.
  def change
    add_column :adozioni, :riportata, :boolean, default: false, null: false
  end
end
