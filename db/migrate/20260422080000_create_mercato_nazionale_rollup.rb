class CreateMercatoNazionaleRollup < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_libri AS
      SELECT "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
             "DISCIPLINA"      AS disciplina,
             "ANNOCORSO"       AS anno_corso,
             "CODICEISBN"      AS codice_isbn,
             COUNT(DISTINCT "CODICESCUOLA" || '_' || "ANNOCORSO" || '_' || "SEZIONEANNO") AS sezioni
      FROM import_adozioni
      WHERE "DAACQUIST" = 'Si'
      GROUP BY 1, 2, 3, 4
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_naz_libri_pk
      ON mercato_nazionale_libri (tipo_grado_scuola, disciplina, anno_corso, codice_isbn)
    SQL

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_mercati AS
      SELECT "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
             "DISCIPLINA"      AS disciplina,
             "ANNOCORSO"       AS anno_corso,
             COUNT(DISTINCT "CODICESCUOLA" || '_' || "ANNOCORSO" || '_' || "SEZIONEANNO") AS sezioni
      FROM import_adozioni
      WHERE "DAACQUIST" = 'Si'
      GROUP BY 1, 2, 3
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_naz_mercati_pk
      ON mercato_nazionale_mercati (tipo_grado_scuola, disciplina, anno_corso)
    SQL
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_mercati"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_libri"
  end
end
