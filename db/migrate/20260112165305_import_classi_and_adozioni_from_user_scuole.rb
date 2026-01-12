class ImportClassiAndAdozioniFromUserScuole < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Insert classi - one per scuola/anno/sezione (skip duplicates)
    say_with_time "Inserting classi" do
      execute <<-SQL
        INSERT INTO classi (
          id,
          account_id,
          scuola_id,
          anno_corso,
          sezione,
          combinazione,
          tipo_scuola,
          codice_ministeriale_origine,
          classe_origine,
          sezione_origine,
          combinazione_origine,
          created_at,
          updated_at
        )
        SELECT
          gen_random_uuid(),
          account_id,
          scuola_id,
          anno_corso,
          sezione,
          combinazione,
          tipo_scuola,
          codice_ministeriale,
          anno_corso,
          sezione,
          combinazione,
          NOW(),
          NOW()
        FROM (
          SELECT DISTINCT ON (s.id, ia."ANNOCORSO", ia."SEZIONEANNO")
            s.account_id,
            s.id AS scuola_id,
            ia."ANNOCORSO" AS anno_corso,
            ia."SEZIONEANNO" AS sezione,
            ia."COMBINAZIONE" AS combinazione,
            isc."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" AS tipo_scuola,
            ia."CODICESCUOLA" AS codice_ministeriale
          FROM scuole s
          JOIN import_adozioni ia ON ia."CODICESCUOLA" = s.codice_ministeriale
          LEFT JOIN import_scuole isc ON isc."CODICESCUOLA" = s.codice_ministeriale
          WHERE s.codice_ministeriale IS NOT NULL
            AND s.codice_ministeriale != ''
          ORDER BY s.id, ia."ANNOCORSO", ia."SEZIONEANNO", ia."COMBINAZIONE"
        ) AS distinct_classi
        ON CONFLICT (scuola_id, anno_corso, sezione) DO NOTHING
      SQL
    end

    # Step 2: Insert adozioni from import_adozioni for each classe
    say_with_time "Inserting adozioni" do
      execute <<-SQL
        INSERT INTO adozioni (
          id,
          account_id,
          classe_id,
          libro_id,
          import_adozione_id,
          codice_isbn,
          titolo,
          editore,
          autori,
          disciplina,
          prezzo_cents,
          nuova_adozione,
          da_acquistare,
          consigliato,
          numero_copie,
          created_at,
          updated_at
        )
        SELECT
          gen_random_uuid(),
          c.account_id,
          c.id,
          l.id,
          ia.id,
          ia."CODICEISBN",
          ia."TITOLO",
          ia."EDITORE",
          ia."AUTORI",
          ia."DISCIPLINA",
          COALESCE(ROUND(NULLIF(REPLACE(ia."PREZZO", ',', '.'), 'ND')::NUMERIC * 100), 0)::INTEGER,
          ia."NUOVAADOZ" = 'Si',
          ia."DAACQUIST" = 'Si',
          ia."CONSIGLIATO" = 'Si',
          0,
          NOW(),
          NOW()
        FROM import_adozioni ia
        JOIN classi c ON c.codice_ministeriale_origine = ia."CODICESCUOLA"
                     AND c.classe_origine = ia."ANNOCORSO"
                     AND c.sezione_origine = ia."SEZIONEANNO"
        LEFT JOIN libri l ON l.codice_isbn = ia."CODICEISBN" AND l.account_id = c.account_id
        ON CONFLICT (classe_id, codice_isbn) DO NOTHING
      SQL
    end

    # Report counts
    classi_count = execute("SELECT COUNT(*) FROM classi WHERE codice_ministeriale_origine IS NOT NULL").first['count']
    adozioni_count = execute("SELECT COUNT(*) FROM adozioni WHERE import_adozione_id IS NOT NULL").first['count']
    say "Total classi with origine: #{classi_count}"
    say "Total adozioni with import_id: #{adozioni_count}"
  end

  def down
    say_with_time "Removing imported adozioni and classi" do
      execute "DELETE FROM adozioni WHERE import_adozione_id IS NOT NULL"
      execute "DELETE FROM classi WHERE codice_ministeriale_origine IS NOT NULL"
    end
  end
end
