class CreateEdizioniTitoli < ActiveRecord::Migration[8.0]
  def change
    create_table :edizioni_titoli do |t|
      t.string :codice_isbn
      t.string :titolo_originale
      t.string :autore

      t.timestamps
    end
    add_index :edizioni_titoli, :codice_isbn, unique: true
  end
end
