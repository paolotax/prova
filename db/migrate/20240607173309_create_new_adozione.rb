class CreateNewAdozione < ActiveRecord::Migration[7.1]
  def change
    create_table :new_adozioni do |t|
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
      t.string :anno_scolastico
      t.bigint :scuola_id
    end

    add_index :new_adozioni, [:anno_scolastico, :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE, :CODICEISBN], unique: true, name: 'index_new_adozioni_on_classe'
  end
end
