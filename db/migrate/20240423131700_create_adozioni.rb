class CreateAdozioni < ActiveRecord::Migration[7.1]
  def change
    create_table :adozioni do |t|
      t.references :user, null: false, foreign_key: true
      t.references :import_adozione, null: false, foreign_key: true
      t.references :libro, null: false, foreign_key: true
      t.string :team
      t.text :note
      t.integer :numero_sezioni
      t.string :stato_adozione
      t.timestamps
    end
  end
end
