class AddLatitudeAndLongitudeToImportScuole < ActiveRecord::Migration[7.2]
  def change
    add_column :import_scuole, :latitude, :float
    add_column :import_scuole, :longitude, :float
  end
end
