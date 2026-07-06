# Punto di non ritorno della fase 1 MIUR: le swing tables (new_adozioni,
# new_scuole, import_adozioni, old_adozioni) spariscono. Al loro posto viste
# SQL con gli stessi nomi e le stesse colonne, che leggono le partizioni di
# miur_adozioni/miur_scuole: i ~25 consumer legacy continuano a funzionare
# invariati finche' i Task 10-16 non li migrano su Miur::*.
#
# I dati non si perdono: ogni riga delle tabelle droppate esiste gia' in
# miur_adozioni/miur_scuole (backfill verificato nei Task 4-6, id preservati).
class ReplaceSwingTablesWithBridgeViews < ActiveRecord::Migration[8.1]
  def up
    # 1. FK verso import_adozioni: le colonne restano (riferimenti storici
    #    id-only, risolvibili nella partizione 202526 dove gli id sono
    #    preservati dal backfill).
    remove_foreign_key :adozioni, :import_adozioni
    remove_foreign_key :adozioni_comunicate, :import_adozioni

    # 2. Viste legacy dipendenti (tutte MATERIALIZED, verificato in pg_class).
    #    view_adozioni_elementari e view_adozioni144ant_editori sono morte:
    #    nessun riferimento nel codice, nessuna query Blazer (verificato).
    execute "DROP MATERIALIZED VIEW IF EXISTS view_classi"
    execute "DROP MATERIALIZED VIEW IF EXISTS view_adozioni_elementari"
    execute "DROP MATERIALIZED VIEW IF EXISTS view_adozioni144ant_editori"

    # 3. Drop tabelle (old_adozioni si porta via la sua FK verso import_scuole).
    #    La staging va droppata prima: creata con LIKE ... INCLUDING DEFAULTS,
    #    il default del suo id dipende dalla sequenza di new_adozioni.
    execute "DROP TABLE IF EXISTS new_adozioni_stg"
    execute "DROP TABLE new_adozioni"
    execute "DROP TABLE old_adozioni"
    execute "DROP TABLE import_adozioni"
    execute "DROP TABLE new_scuole"

    # 4. Partizioni storiche per miur_scuole (allineate a miur_adozioni):
    #    le swing tables accettavano qualunque anno, e i consumer legacy
    #    (test inclusi) scrivono anche anni passati attraverso le viste ponte.
    %w[202425 202526].each do |anno|
      execute "CREATE TABLE miur_scuole_#{anno} PARTITION OF miur_scuole FOR VALUES IN ('#{anno}')"
    end

    # 5. Viste ponte con i vecchi nomi. new_adozioni/new_scuole sono
    #    auto-updatable (SELECT * da una sola tabella): INSERT/DELETE
    #    passano alla partizione giusta via anno_scolastico.
    #    L'anno corrente e' ancorato all'anagrafe scuole (stessa semantica
    #    di Miur.anno_corrente); il COALESCE su miur_adozioni e' un
    #    fallback per ambienti senza anagrafe caricata (test).
    execute <<~SQL
      CREATE VIEW new_adozioni AS
      SELECT * FROM miur_adozioni
      WHERE anno_scolastico = COALESCE(
        (SELECT max(anno_scolastico) FROM miur_scuole),
        (SELECT max(anno_scolastico) FROM miur_adozioni))
    SQL
    execute <<~SQL
      CREATE VIEW new_scuole AS
      SELECT * FROM miur_scuole
      WHERE anno_scolastico = (SELECT max(anno_scolastico) FROM miur_scuole)
    SQL

    # import_adozioni: stesse colonne (stesso ordine) della tabella originale,
    # UPPERCASE incluso. La partizione 202526 conserva gli id originali.
    # created_at/updated_at NON sono esposti: non esistono in miur_adozioni,
    # nessun consumer li legge (verificato), ed esporli come NULL::timestamp
    # renderebbe la vista non scrivibile (AR e activerecord-import includono
    # i timestamp negli INSERT, e PG rifiuta le colonne sintetiche).
    execute <<~SQL
      CREATE VIEW import_adozioni AS
      SELECT id,
             codicescuola    AS "CODICESCUOLA",
             annocorso       AS "ANNOCORSO",
             sezioneanno     AS "SEZIONEANNO",
             tipogradoscuola AS "TIPOGRADOSCUOLA",
             combinazione    AS "COMBINAZIONE",
             disciplina      AS "DISCIPLINA",
             codiceisbn      AS "CODICEISBN",
             autori          AS "AUTORI",
             titolo          AS "TITOLO",
             sottotitolo     AS "SOTTOTITOLO",
             volume          AS "VOLUME",
             editore         AS "EDITORE",
             prezzo          AS "PREZZO",
             nuovaadoz       AS "NUOVAADOZ",
             daacquist       AS "DAACQUIST",
             consigliato     AS "CONSIGLIATO",
             anno_scolastico
      FROM miur_adozioni
      WHERE anno_scolastico = '202526'
    SQL

    # Le viste non ereditano il default dell'id (identity sulla tabella base):
    # senza, i writer bulk legacy (activerecord-import) includono id NULL
    # nell'INSERT invece di lasciarlo alla sequenza, come facevano con il
    # serial delle swing tables.
    execute "ALTER VIEW new_adozioni ALTER COLUMN id SET DEFAULT nextval('miur_adozioni_id_seq')"
    execute "ALTER VIEW import_adozioni ALTER COLUMN id SET DEFAULT nextval('miur_adozioni_id_seq')"
    execute "ALTER VIEW new_scuole ALTER COLUMN id SET DEFAULT nextval('miur_scuole_id_seq')"

    # 6. view_classi ricreata IDENTICA (materializzata, stessa definizione e
    #    stessi indici: i refresh in ImportAdozione/database_update.rake
    #    continuano a funzionare). Ora legge attraverso la vista ponte.
    execute "CREATE MATERIALIZED VIEW view_classi AS #{File.read(Rails.root.join("db/views_legacy/view_classi.sql"))}"
    execute <<~SQL
      CREATE UNIQUE INDEX idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec
        ON view_classi (codice_ministeriale, classe, sezione, combinazione)
    SQL
    execute "CREATE INDEX index_view_classi_on_codice_ministeriale ON view_classi (codice_ministeriale)"
    execute "CREATE INDEX index_view_classi_on_provincia ON view_classi (provincia)"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
