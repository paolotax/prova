class CreatePersone < ActiveRecord::Migration[8.0]
  def change
    create_table :persone, id: :uuid do |t|
      t.references :account, type: :uuid, null: false, foreign_key: true
      t.references :scuola, type: :uuid, foreign_key: true

      t.string :nome
      t.string :cognome
      t.string :ruolo  # docente, dirigente, segretario, altro
      t.string :email
      t.string :telefono
      t.string :cellulare
      t.text :note

      t.timestamps
    end

    add_index :persone, [:account_id, :cognome, :nome]
    add_index :persone, [:scuola_id, :ruolo]
  end
end
