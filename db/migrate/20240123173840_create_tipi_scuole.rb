class CreateTipiScuole < ActiveRecord::Migration[7.1]
  def change
    create_table :tipi_scuole do |t|
      t.string :tipo
      t.string :grado

      t.timestamps
    end
  end
end
