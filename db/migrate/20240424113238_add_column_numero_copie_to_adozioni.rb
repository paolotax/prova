class AddColumnNumeroCopieToAdozioni < ActiveRecord::Migration[7.1]
  def change
    add_column :adozioni, :numero_copie, :integer
    add_column :adozioni, :prezzo_cents, :integer
    add_column :adozioni, :importo_cents, :integer
  end
end
