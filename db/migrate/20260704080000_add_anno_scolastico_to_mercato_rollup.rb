class AddAnnoScolasticoToMercatoRollup < ActiveRecord::Migration[8.1]
  # Le matview di mercato aggregavano import_adozioni senza dimensione anno:
  # con più annate in giro le quote nazionali/zona mescolavano campagne diverse.
  # Ora: anno_scolastico nel GROUP BY + UNION con new_adozioni (campagna corrente),
  # così AdozioniAnalytics confronta sempre annate omogenee.
  def up
    # work_mem alto (memoria privata del backend, non shm): serve al NOT IN
    # del dedup per usare un hashed subplan sui ~3.4M di MIN(id) — sotto la
    # soglia di memoria il planner ripiega su un subplan lineare per riga.
    execute "SET work_mem = '256MB'"

    # Backfill una tantum delle righe caricate prima della timbratura dell'anno:
    # import_adozioni è lo snapshot ministeriale della campagna 2025/26;
    # new_adozioni viene timbrata da import:new_adozioni (anno da new_scuole).
    execute <<~SQL
      UPDATE import_adozioni SET anno_scolastico = '202526' WHERE anno_scolastico IS NULL
    SQL

    # Riallinea l'indice unique di new_adozioni a quello che import:new_adozioni
    # costruisce sulla staging (include disciplina: i Sussidiari delle Discipline
    # adottati su più ambiti condividono ISBN ma differiscono per disciplina).
    # Prima il dedup dei duplicati ESATTI ministeriali, poi l'indice, poi il
    # backfill dell'anno (che altrimenti farebbe collidere le righe pre-timbratura).
    # Tieni una sola riga per gruppo (id minimo). Due forme SCARTATE su new_adozioni
    # (milioni di righe): il self-join `a.id > b.id AND ... IS NOT DISTINCT FROM ...`
    # e' O(n^2); e `id NOT IN (SELECT MIN(id) GROUP BY ...)` sembra O(n) ma Postgres,
    # per la semantica NULL del NOT IN, non usa l'anti-join hash e ripiega su un
    # subplan per-riga (di nuovo lentissimo). ROW_NUMBER + join sull'id (PK) e'
    # un solo scan + sort O(n log n). PARTITION BY tratta i NULL come uguali.
    execute <<~SQL
      DELETE FROM new_adozioni na
      USING (
        SELECT id, ROW_NUMBER() OVER (
          PARTITION BY anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina
          ORDER BY id
        ) AS rn
        FROM new_adozioni
      ) d
      WHERE d.id = na.id AND d.rn > 1
    SQL
    execute "DROP INDEX IF EXISTS index_new_adozioni_on_classe"
    execute <<~SQL
      CREATE UNIQUE INDEX index_new_adozioni_on_classe
      ON new_adozioni (anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina)
    SQL

    execute <<~SQL
      UPDATE new_adozioni
      SET anno_scolastico = (SELECT MAX(anno_scolastico) FROM new_scuole)
      WHERE anno_scolastico IS NULL
        AND EXISTS (SELECT 1 FROM new_scuole WHERE anno_scolastico IS NOT NULL)
    SQL

    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_libri"
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
    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_naz_libri_pk
      ON mercato_nazionale_libri (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso, codice_isbn)
    SQL

    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_mercati"
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
    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_naz_mercati_pk
      ON mercato_nazionale_mercati (anno_scolastico, tipo_grado_scuola, disciplina, anno_corso)
    SQL

    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_scuola_mercati"
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
    execute <<~SQL
      CREATE UNIQUE INDEX idx_mercato_scuola_mercati_pk
      ON mercato_scuola_mercati (anno_scolastico, codice_scuola, tipo_grado_scuola, disciplina, anno_corso)
    SQL
    execute <<~SQL
      CREATE INDEX idx_mercato_scuola_mercati_scuola
      ON mercato_scuola_mercati (codice_scuola)
    SQL
  end

  def down
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_scuola_mercati"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_mercati"
    execute "DROP MATERIALIZED VIEW IF EXISTS mercato_nazionale_libri"

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
end
