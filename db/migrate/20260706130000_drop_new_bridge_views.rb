# Task 17 (Fase 1 MIUR): le viste ponte new_adozioni/new_scuole hanno esaurito
# il loro scopo — tutti i consumer (produzione + test) leggono ormai
# Miur::Adozione/Miur::Scuola. Le rimuoviamo.
#
# import_adozioni RESTA (scelta A): Adozione e AdozioneComunicata mantengono
# belongs_to :import_adozione (id-only, risolto nella partizione 202526 dove
# gli id sono preservati) e differenze_con_import_adozione legge le colonne
# UPPERCASE via l'associazione. La rimozione completa + il repunta delle
# associazioni su Miur::Adozione (PK composita) e' rinviata alla Fase 2.
#
# view_classi (materializzata) veniva ricostruita leggendo la vista ponte
# import_adozioni: la ripuntiamo direttamente su miur_adozioni WHERE
# anno_scolastico='202526', rimuovendo un livello di indirezione. Contenuto,
# colonne e indici restano identici (import_adozioni e' esattamente
# miur_adozioni della partizione 202526).
class DropNewBridgeViews < ActiveRecord::Migration[8.1]
  def up
    # 1. Ripunta view_classi su miur_adozioni (stessa definizione, stessi indici).
    execute "DROP MATERIALIZED VIEW view_classi"
    execute <<~SQL
      CREATE MATERIALIZED VIEW view_classi AS
      SELECT DISTINCT row_number() OVER (PARTITION BY true::boolean) AS id,
          import_scuole."AREAGEOGRAFICA" AS area_geografica,
          import_scuole."REGIONE" AS regione,
          import_scuole."PROVINCIA" AS provincia,
          import_scuole."CODICESCUOLA" AS codice_ministeriale,
          miur_adozioni.annocorso AS classe,
          miur_adozioni.sezioneanno AS sezione,
          miur_adozioni.combinazione AS combinazione,
          array_agg(miur_adozioni.id) AS import_adozioni_ids,
          import_scuole."ANNOSCOLASTICO" AS anno
         FROM import_scuole
           JOIN miur_adozioni ON miur_adozioni.codicescuola::text = import_scuole."CODICESCUOLA"::text
        WHERE miur_adozioni.anno_scolastico = '202526'
        GROUP BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA",
                 import_scuole."CODICESCUOLA", miur_adozioni.annocorso, miur_adozioni.sezioneanno,
                 miur_adozioni.combinazione, import_scuole."ANNOSCOLASTICO"
        ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA",
                 import_scuole."CODICESCUOLA", miur_adozioni.annocorso, miur_adozioni.sezioneanno,
                 miur_adozioni.combinazione
    SQL
    execute <<~SQL
      CREATE UNIQUE INDEX idx_on_codice_ministeriale_classe_sezione_combinazi_79414f61ec
        ON view_classi (codice_ministeriale, classe, sezione, combinazione)
    SQL
    execute "CREATE INDEX index_view_classi_on_codice_ministeriale ON view_classi (codice_ministeriale)"
    execute "CREATE INDEX index_view_classi_on_provincia ON view_classi (provincia)"

    # 2. Drop viste ponte non piu' usate.
    execute "DROP VIEW new_adozioni"
    execute "DROP VIEW new_scuole"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
