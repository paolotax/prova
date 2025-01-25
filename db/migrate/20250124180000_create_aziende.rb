class CreateAziende < ActiveRecord::Migration[7.1]
  def change

    remove_column :users, :partita_iva, :string

    
    create_table :aziende do |t|
      t.references :user, null: false, foreign_key: true
      
      # Dati anagrafici
      t.string :partita_iva, limit: 11, null: false
      t.string :codice_fiscale, limit: 16, null: false
      t.string :ragione_sociale, null: false
      t.string :regime_fiscale, null: false, default: 'RF19'
      
      # Sede
      t.string :indirizzo, null: false
      t.string :cap, limit: 5, null: false
      t.string :comune, null: false
      t.string :provincia, limit: 2, null: false
      t.string :nazione, limit: 2, null: false, default: 'IT'
      
      # Contatti
      t.string :email, null: false
      t.string :telefono
      t.string :indirizzo_telematico, limit: 7  # Codice Destinatario SDI
      
      # Dati bancari
      t.string :iban, limit: 27
      t.string :banca
      
      t.timestamps
    end

    add_index :aziende, :partita_iva, unique: true
    add_index :aziende, :codice_fiscale, unique: true
  end
end 