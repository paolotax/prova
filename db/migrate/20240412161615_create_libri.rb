class CreateLibri < ActiveRecord::Migration[7.1]
  def change
    create_table :libri do |t|
      t.references :user, null: false, foreign_key: true
      t.references :editore, null: false, foreign_key: true
      t.string :titolo
      t.string :codice_isbn
      t.integer :prezzo_in_cents
      t.integer :classe
      t.string :disciplina
      t.text :note
      t.string :categoria

      t.timestamps
    end

    add_index :libri, [:user_id, :titolo]
    add_index :libri, [:user_id, :editore_id]
    add_index :libri, [:user_id, :codice_isbn]
    add_index :libri, [:user_id, :categoria]
    add_index :libri, [:classe, :disciplina]
  end
end
