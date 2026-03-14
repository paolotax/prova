class RenameReferenteToContattoInBolleVisione < ActiveRecord::Migration[8.1]
  def change
    rename_column :bolle_visione, :referente_id, :contatto_id
  end
end
