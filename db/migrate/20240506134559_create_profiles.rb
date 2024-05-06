class CreateProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :profiles do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :nome
      t.string :cognome
      t.string :ragione_sociale
      t.string :indirizzo
      t.string :cap
      t.string :citta
      t.string :cellulare
      t.string :email
      t.string :iban
      t.string :nome_banca

      t.timestamps
    end
  end
end
