class CreateImports < ActiveRecord::Migration[7.1]
  def change
    create_table :imports do |t|

      t.string :fornitore
      t.string :tipo_documento
      t.string :numero_documento
      t.date   :data_documento
      t.float  :totale_documento

      t.integer :riga
      t.string  :codice_articolo
      t.string  :descrizione
      
      t.float   :prezzo_unitario
      t.integer :quantita
      t.float   :importo_netto     
      t.float   :sconto
      t.integer :iva

    end
  end
end
