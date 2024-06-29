class FixNewAdozioniColumns < ActiveRecord::Migration[7.1]
  def change

    change_table(:new_adozioni) do |t|
      t.rename(:ANNOCORSO, :annocorso)
      t.rename(:AUTORI, :autori)
      t.rename(:CODICEISBN, :codiceisbn)
      t.rename(:CODICESCUOLA, :codicescuola)
      t.rename(:COMBINAZIONE, :combinazione)
      t.rename(:CONSIGLIATO, :consigliato)
      t.rename(:DAACQUIST, :daacquist)
      t.rename(:DISCIPLINA, :disciplina)
      t.rename(:EDITORE, :editore)
      t.rename(:NUOVAADOZ, :nuovaadoz)
      t.rename(:PREZZO, :prezzo)
      t.rename(:SEZIONEANNO, :sezioneanno)
      t.rename(:SOTTOTITOLO, :sottotitolo)
      t.rename(:TIPOGRADOSCUOLA, :tipogradoscuola)
      t.rename(:TITOLO, :titolo)
      t.rename(:VOLUME, :volume)
      t.rename(:scuola_id, :import_scuola_id)
    end

  end
end
