class CreateOldAdozioni < ActiveRecord::Migration[8.0]
  def change
    create_table :old_adozioni do |t|
      t.string :codicescuola
      t.string :annocorso
      t.string :sezioneanno
      t.string :tipogradoscuola
      t.string :combinazione
      t.string :disciplina
      t.string :codiceisbn
      t.string :autori
      t.string :titolo
      t.string :sottotitolo
      t.string :volume
      t.string :editore
      t.string :prezzo
      t.string :nuovaadoz
      t.string :daacquist
      t.string :consigliato
      t.string :anno_scolastico
      t.references :import_scuola, null: true, foreign_key: { to_table: :import_scuole }

      t.timestamps
    end

    # Aggiungo l'indice unico come in new_adozioni
    add_index :old_adozioni, [:anno_scolastico, :codicescuola, :annocorso, :sezioneanno, :combinazione, :codiceisbn], 
               unique: true, name: 'index_old_adozioni_on_classe'
  end
end