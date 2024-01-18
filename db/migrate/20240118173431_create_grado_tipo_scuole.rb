class CreateGradoTipoScuole < ActiveRecord::Migration[7.1]
  def change
    create_table :grado_tipo_scuole do |t|
      t.string :grado
      t.string :tipo

      t.timestamps
    end
  end
end
