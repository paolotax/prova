class CreateGiri < ActiveRecord::Migration[7.1]
  def change
    create_table :giri do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :iniziato_il
      t.datetime :finito_il
      t.string :titolo
      t.string :descrizione
      t.string :stato
      
      t.timestamps
    end
  end
end
