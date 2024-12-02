class AddCoordinatesAndGeocodedToClienti < ActiveRecord::Migration[7.2]
  def change
    add_column :clienti, :latitude, :float
    add_column :clienti, :longitude, :float
    add_column :clienti, :geocoded, :boolean
  end
end
