class AddScontoDefiscalizzatoToAziende < ActiveRecord::Migration[8.1]
  def change
    add_column :aziende, :sconto_defiscalizzato, :boolean, default: false, null: false
  end
end
