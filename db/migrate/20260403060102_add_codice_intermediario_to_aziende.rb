class AddCodiceIntermediarioToAziende < ActiveRecord::Migration[8.1]
  def change
    add_column :aziende, :codice_intermediario, :string, default: "01879020517"
  end
end
