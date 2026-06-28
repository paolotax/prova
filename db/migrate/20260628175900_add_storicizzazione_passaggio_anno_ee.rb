class AddStoricizzazionePassaggioAnnoEe < ActiveRecord::Migration[8.1]
  # Deploy-safe su adozioni (>1M righe): niente mass UPDATE né rebuild di indici
  # unique dentro un'unica transazione DDL. Indici concorrenti + backfill batched.
  disable_ddl_transaction!

  ANNO_PRECEDENTE = "202526" # dati esistenti = anno scolastico in corso fino al rollover

  def up
    # 1. Colonne: metadata-only in PG11+, veloci anche su tabelle grandi.
    add_column :classi, :anno_scolastico, :string unless column_exists?(:classi, :anno_scolastico)
    add_column :classi, :stato, :string, null: false, default: "attiva" unless column_exists?(:classi, :stato)
    add_column :adozioni, :anno_scolastico, :string unless column_exists?(:adozioni, :anno_scolastico)
    add_column :adozioni, :codicescuola, :string unless column_exists?(:adozioni, :codicescuola)

    # 2. Backfill batched (transazioni piccole). Guard IS NULL = re-runnable.
    say "Backfill classi.anno_scolastico in batch..."
    Classe.unscoped.where(anno_scolastico: nil).in_batches(of: 10_000) do |batch|
      batch.update_all(anno_scolastico: ANNO_PRECEDENTE)
    end

    say "Backfill adozioni.anno_scolastico + codicescuola in batch..."
    Adozione.unscoped.where(anno_scolastico: nil).in_batches(of: 10_000) do |batch|
      batch.update_all(
        "anno_scolastico = '#{ANNO_PRECEDENTE}', " \
        "codicescuola = (SELECT codice_ministeriale_origine FROM classi WHERE classi.id = adozioni.classe_id)"
      )
    end

    # 3. Nuovi indici, build concorrente (no lock sulle scritture).
    add_index :classi, %i[scuola_id anno_corso sezione combinazione],
              unique: true, where: "stato = 'attiva'",
              name: "index_classi_attive_on_scuola_anno_sezione_combinazione",
              algorithm: :concurrently, if_not_exists: true

    add_index :adozioni, %i[classe_id codice_isbn anno_scolastico],
              unique: true, name: "index_adozioni_on_classe_isbn_anno",
              algorithm: :concurrently, if_not_exists: true

    add_index :classi, %i[account_id anno_scolastico],
              algorithm: :concurrently, if_not_exists: true
    add_index :adozioni, %i[account_id anno_scolastico],
              algorithm: :concurrently, if_not_exists: true

    # 4. Rimozione vecchi indici unique SOLO dopo aver costruito i nuovi.
    remove_index :classi, name: "index_classi_on_scuola_anno_sezione_combinazione",
                 algorithm: :concurrently, if_exists: true
    remove_index :adozioni, name: "index_adozioni_on_classe_id_and_codice_isbn",
                 algorithm: :concurrently, if_exists: true
  end

  def down
    # Ricostruisci i vecchi indici unique prima di rimuovere i nuovi.
    add_index :classi, %i[scuola_id anno_corso sezione combinazione],
              unique: true, name: "index_classi_on_scuola_anno_sezione_combinazione",
              algorithm: :concurrently, if_not_exists: true
    add_index :adozioni, %i[classe_id codice_isbn],
              unique: true, name: "index_adozioni_on_classe_id_and_codice_isbn",
              algorithm: :concurrently, if_not_exists: true

    remove_index :adozioni, name: "index_adozioni_on_classe_isbn_anno",
                 algorithm: :concurrently, if_exists: true
    remove_index :classi, name: "index_classi_attive_on_scuola_anno_sezione_combinazione",
                 algorithm: :concurrently, if_exists: true
    remove_index :adozioni, %i[account_id anno_scolastico],
                 algorithm: :concurrently, if_exists: true
    remove_index :classi, %i[account_id anno_scolastico],
                 algorithm: :concurrently, if_exists: true

    remove_column :adozioni, :codicescuola
    remove_column :adozioni, :anno_scolastico
    remove_column :classi, :stato
    remove_column :classi, :anno_scolastico
  end
end
