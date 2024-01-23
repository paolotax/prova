class CreateZone < ActiveRecord::Migration[7.1]
  def change
    create_table :zone do |t|
      t.string :area_geografica
      t.string :regione
      t.string :provincia
      t.string :comune
      t.string :codice_comune

      t.timestamps
    end
  end
end
