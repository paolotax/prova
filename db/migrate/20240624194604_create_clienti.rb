class CreateClienti < ActiveRecord::Migration[7.1]
  def change
    create_table :clienti do |t|
      t.string :codice_cliente
      t.string :tipo_cliente
      t.string :indirizzo_telematico
      t.string :email
      t.string :pec
      t.string :telefono
      t.string :id_paese
      t.string :partita_iva
      t.string :codice_fiscale
      t.string :denominazione
      t.string :nome
      t.string :cognome
      t.string :codice_eori
      t.string :nazione
      t.string :cap
      t.string :provincia
      t.string :comune
      t.string :indirizzo
      t.string :numero_civico
      t.string :beneficiario
      t.string :condizioni_di_pagamento
      t.string :metodo_di_pagamento
      t.string :banca

      t.timestamps
    end
  end
end
