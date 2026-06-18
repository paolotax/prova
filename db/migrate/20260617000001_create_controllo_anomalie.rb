class CreateControlloAnomalie < ActiveRecord::Migration[8.1]
  def change
    create_table :controllo_anomalie, id: :uuid do |t|
      t.string  :anno_scolastico
      t.string  :codicescuola, null: false
      t.string  :annocorso
      t.string  :sezioneanno
      t.string  :combinazione
      t.string  :regione
      t.string  :provincia
      t.string  :comune
      t.string  :denominazione
      t.string  :tipo, null: false
      t.string  :disciplina
      t.string  :codiceisbn
      t.string  :titolo
      t.string  :editore
      t.integer :prezzo_cents
      t.integer :prezzo_atteso_cents
      t.integer :delta_cents
      t.jsonb   :dettaglio, null: false, default: {}
      t.timestamps
    end

    add_index :controllo_anomalie, [:codicescuola]
    add_index :controllo_anomalie, [:anno_scolastico, :codicescuola]
    add_index :controllo_anomalie, [:tipo]
    add_index :controllo_anomalie, [:provincia]
  end
end
