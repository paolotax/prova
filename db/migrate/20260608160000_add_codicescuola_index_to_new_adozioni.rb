class AddCodicescuolaIndexToNewAdozioni < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! # richiesto da algorithm: :concurrently

  # Lookup `codicescuola = X` su new_adozioni: nessun indice esistente lo serve.
  # idx_new_adoz_ee è parziale (WHERE tipogradoscuola='EE') e l'unique sulla
  # classe ha anno_scolastico come colonna guida, non codicescuola. Le Stats con
  # subquery EXISTS (es. "scuole rilevate") facevano un seq scan di new_adozioni
  # (1.3M righe) per ogni scuola -> ~4.6s. import_adozioni non soffre perche' la
  # sua PK inizia con CODICESCUOLA. TRUNCATE RESTART IDENTITY conserva l'indice.
  def up
    add_index :new_adozioni, :codicescuola,
              name: "idx_new_adozioni_codicescuola",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :new_adozioni, name: "idx_new_adozioni_codicescuola", algorithm: :concurrently, if_exists: true
  end
end
