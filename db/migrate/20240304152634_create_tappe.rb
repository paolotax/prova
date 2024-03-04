class CreateTappe < ActiveRecord::Migration[7.1]
  def change
    create_table :tappe do |t|
      t.string :titolo
      t.string :giro
      t.integer :ordine
      t.datetime :data_tappa
      t.datetime :entro_il
      t.references :user, null: false, foreign_key: true
      t.references :tappable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
