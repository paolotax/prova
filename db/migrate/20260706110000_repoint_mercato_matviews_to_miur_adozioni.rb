class RepointMercatoMatviewsToMiurAdozioni < ActiveRecord::Migration[8.1]
  # Le matview di mercato leggevano la UNION delle due swing tables
  # (import_adozioni + new_adozioni). Con miur_adozioni popolata (partizionata
  # per anno_scolastico, backfill completo incluso 202425 da old_adozioni),
  # la subquery si riduce a una SELECT sola. Prerequisito per il drop delle
  # vecchie tabelle: le matview non devono piu' dipenderne.

  def up
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_libri"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_mercati"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_scuola_mercati"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_libri AS
      SELECT anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn,
             COUNT(DISTINCT sezione_key) AS sezioni
      FROM (
        SELECT anno_scolastico,
               tipogradoscuola AS tipo_grado_scuola,
               disciplina,
               annocorso       AS anno_corso,
               codiceisbn      AS codice_isbn,
               codicescuola || '_' || annocorso || '_' || sezioneanno AS sezione_key
        FROM miur_adozioni
        WHERE daacquist = 'Si'
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4, 5
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_naz_libri_pk ON mercato_nazionale_libri (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn)"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_mercati AS
      SELECT anno_scolastico, tipo_grado_scuola, disciplina, anno_corso,
             COUNT(DISTINCT sezione_key) AS sezioni
      FROM (
        SELECT anno_scolastico,
               tipogradoscuola AS tipo_grado_scuola,
               disciplina,
               annocorso       AS anno_corso,
               codicescuola || '_' || annocorso || '_' || sezioneanno AS sezione_key
        FROM miur_adozioni
        WHERE daacquist = 'Si'
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_naz_mercati_pk ON mercato_nazionale_mercati (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso)"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_scuola_mercati AS
      SELECT anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso,
             COUNT(DISTINCT sezione) AS sezioni
      FROM (
        SELECT anno_scolastico,
               codicescuola    AS codice_scuola,
               tipogradoscuola AS tipo_grado_scuola,
               disciplina,
               annocorso       AS anno_corso,
               sezioneanno     AS sezione
        FROM miur_adozioni
        WHERE daacquist = 'Si'
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4, 5
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_scuola_mercati_pk ON mercato_scuola_mercati (anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso)"
    execute "CREATE INDEX idx_mercato_scuola_mercati_scuola ON mercato_scuola_mercati (codice_scuola)"
  end

  # Ripristina le definizioni UNION su import_adozioni + new_adozioni
  # (identiche alla migrazione 20260704080000). NOTA: valido solo finche'
  # esistono le vecchie tabelle — dopo il loro drop (Task 9 del piano
  # 2026-07-06-miur-unificazione-fase1) questo rollback fallisce.
  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_libri"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_mercati"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_scuola_mercati"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_libri AS
      SELECT anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn,
             COUNT(DISTINCT sezione_key) AS sezioni
      FROM (
        SELECT anno_scolastico,
               "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
               "DISCIPLINA"      AS disciplina,
               "ANNOCORSO"       AS anno_corso,
               "CODICEISBN"      AS codice_isbn,
               "CODICESCUOLA" || '_' || "ANNOCORSO" || '_' || "SEZIONEANNO" AS sezione_key
        FROM import_adozioni
        WHERE "DAACQUIST" = 'Si' AND anno_scolastico IS NOT NULL
        UNION ALL
        SELECT anno_scolastico, tipogradoscuola, disciplina, annocorso, codiceisbn,
               codicescuola || '_' || annocorso || '_' || sezioneanno
        FROM new_adozioni
        WHERE daacquist = 'Si' AND anno_scolastico IS NOT NULL
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4, 5
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_naz_libri_pk ON mercato_nazionale_libri (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn)"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_nazionale_mercati AS
      SELECT anno_scolastico, tipo_grado_scuola, disciplina, anno_corso,
             COUNT(DISTINCT sezione_key) AS sezioni
      FROM (
        SELECT anno_scolastico,
               "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
               "DISCIPLINA"      AS disciplina,
               "ANNOCORSO"       AS anno_corso,
               "CODICESCUOLA" || '_' || "ANNOCORSO" || '_' || "SEZIONEANNO" AS sezione_key
        FROM import_adozioni
        WHERE "DAACQUIST" = 'Si' AND anno_scolastico IS NOT NULL
        UNION ALL
        SELECT anno_scolastico, tipogradoscuola, disciplina, annocorso,
               codicescuola || '_' || annocorso || '_' || sezioneanno
        FROM new_adozioni
        WHERE daacquist = 'Si' AND anno_scolastico IS NOT NULL
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_naz_mercati_pk ON mercato_nazionale_mercati (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso)"

    execute <<~SQL
      CREATE MATERIALIZED VIEW mercato_scuola_mercati AS
      SELECT anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso,
             COUNT(DISTINCT sezione) AS sezioni
      FROM (
        SELECT anno_scolastico,
               "CODICESCUOLA"    AS codice_scuola,
               "TIPOGRADOSCUOLA" AS tipo_grado_scuola,
               "DISCIPLINA"      AS disciplina,
               "ANNOCORSO"       AS anno_corso,
               "SEZIONEANNO"     AS sezione
        FROM import_adozioni
        WHERE "DAACQUIST" = 'Si' AND anno_scolastico IS NOT NULL
        UNION ALL
        SELECT anno_scolastico, codicescuola, tipogradoscuola, disciplina, annocorso, sezioneanno
        FROM new_adozioni
        WHERE daacquist = 'Si' AND anno_scolastico IS NOT NULL
      ) adozioni_annate
      GROUP BY 1, 2, 3, 4, 5
    SQL
    execute "CREATE UNIQUE INDEX idx_mercato_scuola_mercati_pk ON mercato_scuola_mercati (anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso)"
    execute "CREATE INDEX idx_mercato_scuola_mercati_scuola ON mercato_scuola_mercati (codice_scuola)"
  end
end
