class CreateAppunti < ActiveRecord::Migration[7.1]
  def change
    create_table :appunti do |t|
      t.references :import_scuola, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :import_adozione, null: true, foreign_key: true
      t.string :nome
      t.text :body 
      t.string :email
      t.string :telefono
      t.string :stato
      t.timestamps
    end
  end
end
