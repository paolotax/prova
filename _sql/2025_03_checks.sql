-- Checks aggiornamento scuole

-- 1. Nuove Scuole
SELECT COUNT(*) as nuove_scuole
FROM new_scuole ns
WHERE NOT EXISTS (
    SELECT 1
    FROM import_scuole i
    WHERE i."CODICESCUOLA" = ns.codice_scuola
);

-- 2. Verifica aggiunte/aggiornate
SELECT COUNT(*) as scuole_aggiornate
FROM new_scuole ns
WHERE EXISTS (
SELECT
    COUNT(*) as totale_import_scuole,
    COUNT(DISTINCT "CODICESCUOLA") as scuole_distinte
FROM import_scuole);

-- 5. Lista scuole aggiunte/aggiornate
SELECT
    "CODICESCUOLA",
    "DENOMINAZIONESCUOLA",
    "PROVINCIA",
    created_at,
    updated_at
FROM import_scuole
WHERE updated_at >= NOW() - INTERVAL '1 minute'
ORDER BY updated_at DESC;





-- Checks aggiornamento adozioni

SELECT 'old_adozioni' AS tabella, COUNT(*) AS record_count FROM old_adozioni
UNION ALL
SELECT 'import_adozioni' AS tabella, COUNT(*) AS record_count FROM import_adozioni
UNION ALL
SELECT 'new_adozioni' AS tabella, COUNT(*) AS record_count FROM new_adozioni;

-- Verify no duplicates exist for the unique key in import_adozioni (sanity)
SELECT
  'duplicati_key_import_adozioni' AS descrizione,
  COUNT(*) AS count
FROM (
  SELECT anno_scolastico, "CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "COMBINAZIONE", "CODICEISBN"
  FROM import_adozioni
  GROUP BY anno_scolastico, "CODICESCUOLA", "ANNOCORSO", "SEZIONEANNO", "COMBINAZIONE", "CODICEISBN"
  HAVING COUNT(*) > 1
) d;

-- Join coverage
SELECT
  'scuole_matchate'  AS descrizione, COUNT(*) AS count
FROM old_adozioni
WHERE import_scuola_id IS NOT NULL
UNION ALL
SELECT
  'scuole_non_matchate' AS descrizione, COUNT(*) AS count
FROM old_adozioni
WHERE import_scuola_id IS NULL;