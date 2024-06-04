class AddAnnoScolasticoToImportAdozioni < ActiveRecord::Migration[7.1]
  def change
    add_column :import_adozioni, :anno_scolastico, :string
  end
end
