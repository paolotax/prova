# Fase 1 MIUR: ripunta view_classi (materializzata) direttamente su
# miur_adozioni WHERE anno_scolastico='202526', invece che sulla vista ponte
# import_adozioni — rimuove un livello di indirezione. Contenuto, colonne e
# indici restano identici (import_adozioni e' esattamente miur_adozioni della
# partizione 202526).
#
# NOTA (2026-07-06, revisione): questa migrazione NON droppa piu' le viste
# ponte new_adozioni/new_scuole. Non sono impalcatura interna: sono
# l'interfaccia pubblica su cui gli utenti scrivono l'SQL a mano delle Stat
# (classifiche). 49/60 stat referenziano new_adozioni, 41 new_scuole. Restano
# permanenti, come import_adozioni. Il codice applicativo legge Miur::*; le
# tre viste ponte servono solo alle query utente.
class RepointViewClassiToMiurAdozioni < ActiveRecord::Migration[8.1]
  def up
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
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
