class CreateImportAdozioni < ActiveRecord::Migration[7.1]
  def change
    create_table :import_adozioni do |t|
      t.string :CODICESCUOLA
      t.string :ANNOCORSO
      t.string :SEZIONEANNO
      t.string :TIPOGRADOSCUOLA
      t.string :COMBINAZIONE
      t.string :DISCIPLINA
      t.string :CODICEISBN
      t.string :AUTORI
      t.string :TITOLO
      t.string :SOTTOTITOLO
      t.string :VOLUME
      t.string :EDITORE
      t.string :PREZZO
      t.string :NUOVAADOZ
      t.string :DAACQUIST
      t.string :CONSIGLIATO

      t.timestamps
    end
  end
end
