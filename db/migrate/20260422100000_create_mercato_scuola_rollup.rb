class CreateMercatoScuolaRollup < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_scuola_mercati AS
      SELECT "CODICESCUOLA"    AS codice_scuola,
             "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
             "DISCIPLINA"      AS disciplina,
             "ANNOCORSO"       AS anno_corso,
             COUNT(DISTINCT "SEZIONEANNO") AS sezioni
      FROM import_adozioni
      WHERE "DAACQUIST" = 'Si'
      GROUP BY 1, 2, 3, 4
    SQL

    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_scuola_mercati_pk
      ON mercato_scuola_mercati (codice_scuola, tipo_grado_scuola, disciplina, anno_corso)
    SQL

    execute <<~SQL
      CREATE INDEX idx_mercato_scuola_mercati_scuola
      ON mercato_scuola_mercati (codice_scuola)
    SQL
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_scuola_mercati"
  end
end
