class RicreaAdozioniComunicate < ActiveRecord::Migration[8.1]
  # La tabella 2025/26 (bigint, user_id, matching su id MIUR volatili) era il
  # controllo dell'anno scorso, ormai consumato: si riparte dalle convenzioni
  # correnti (uuid, account_id, no FK) e dal matching su Adozione/Classe propri.
  def up
    drop_table :adozioni_comunicate

    create_table :adozioni_comunicate, id: :uuid do |t|
      t.uuid    :account_id, null: false
      t.string  :anno_scolastico, null: false
      t.string  :editore
      t.string  :fonte, null: false, default: "excel"
      t.uuid    :import_record_id

      t.string  :codicescuola, null: false
      t.string  :ean, null: false
      t.string  :titolo
      t.string  :anno_corso, null: false
      t.string  :sezioni, null: false, default: ""
      t.integer :alunni, null: false

      t.uuid    :adozione_id
      t.uuid    :classe_id
      t.string  :stato_match, null: false, default: "da_verificare"

      t.string  :descrizione_scuola
      t.string  :comune
      t.string  :provincia

      t.timestamps
    end

    add_index :adozioni_comunicate,
              %i[account_id anno_scolastico codicescuola ean anno_corso sezioni],
              unique: true, name: "index_adozioni_comunicate_unicita"
    add_index :adozioni_comunicate, %i[account_id stato_match]
    add_index :adozioni_comunicate, :adozione_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
