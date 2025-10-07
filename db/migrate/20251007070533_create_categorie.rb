class CreateCategorie < ActiveRecord::Migration[8.0]
  def change
    create_table :categorie do |t|
      t.string :nome_categoria, null: false
      t.text :descrizione

      t.timestamps
    end

    add_index :categorie, :nome_categoria, unique: true
  end
end
