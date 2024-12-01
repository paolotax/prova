class AddGeocodedToImportScuola < ActiveRecord::Migration[7.2]
  def change
    add_column :import_scuole, :geocoded, :boolean
  end
end
