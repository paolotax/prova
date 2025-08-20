-- Script per trasferire dati tra tabelle adozioni (con deduplicazione completa)
-- Data: 2025-01-19

BEGIN;

-- 1) Upsert from import_adozioni into old_adozioni
WITH deduplicated_import_adozioni AS (
  SELECT DISTINCT ON (
      ia.anno_scolastico,
      ia."CODICESCUOLA",
      ia."ANNOCORSO",
      ia."SEZIONEANNO",
      ia."COMBINAZIONE",
      ia."CODICEISBN"
  )
    ia."CODICESCUOLA",
    ia."ANNOCORSO",
    ia."SEZIONEANNO",
    ia."TIPOGRADOSCUOLA",
    ia."COMBINAZIONE",
    ia."DISCIPLINA",
    ia."CODICEISBN",
    ia."AUTORI",
    ia."TITOLO",
    ia."SOTTOTITOLO",
    ia."VOLUME",
    ia."EDITORE",
    ia."PREZZO",
    ia."NUOVAADOZ",
    ia."DAACQUIST",
    ia."CONSIGLIATO",
    ia.anno_scolastico,
    iscuole.id AS import_scuola_id,
    ia.created_at,
    ia.updated_at
  FROM import_adozioni ia
  LEFT JOIN import_scuole iscuole ON ia."CODICESCUOLA" = iscuole."CODICESCUOLA"
  ORDER BY
    ia.anno_scolastico,
    ia."CODICESCUOLA",
    ia."ANNOCORSO",
    ia."SEZIONEANNO",
    ia."COMBINAZIONE",
    ia."CODICEISBN",
    ia.updated_at DESC NULLS LAST,
    ia.created_at DESC NULLS LAST,
    ia.id DESC
)
INSERT INTO old_adozioni (
  codicescuola,
  annocorso,
  sezioneanno,
  tipogradoscuola,
  combinazione,
  disciplina,
  codiceisbn,
  autori,
  titolo,
  sottotitolo,
  volume,
  editore,
  prezzo,
  nuovaadoz,
  daacquist,
  consigliato,
  anno_scolastico,
  import_scuola_id,
  created_at,
  updated_at
)
SELECT
  "CODICESCUOLA" AS codicescuola,
  "ANNOCORSO" AS annocorso,
  "SEZIONEANNO" AS sezioneanno,
  "TIPOGRADOSCUOLA" AS tipogradoscuola,
  "COMBINAZIONE" AS combinazione,
  "DISCIPLINA" AS disciplina,
  "CODICEISBN" AS codiceisbn,
  "AUTORI" AS autori,
  "TITOLO" AS titolo,
  "SOTTOTITOLO" AS sottotitolo,
  "VOLUME" AS volume,
  "EDITORE" AS editore,
  "PREZZO" AS prezzo,
  "NUOVAADOZ" AS nuovaadoz,
  "DAACQUIST" AS daacquist,
  "CONSIGLIATO" AS consigliato,
  anno_scolastico,
  import_scuola_id,
  created_at,
  updated_at
FROM deduplicated_import_adozioni
ON CONFLICT (
  anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione, codiceisbn
)
DO UPDATE SET
  tipogradoscuola = EXCLUDED.tipogradoscuola,
  disciplina      = EXCLUDED.disciplina,
  autori          = EXCLUDED.autori,
  titolo          = EXCLUDED.titolo,
  sottotitolo     = EXCLUDED.sottotitolo,
  volume          = EXCLUDED.volume,
  editore         = EXCLUDED.editore,
  prezzo          = EXCLUDED.prezzo,
  nuovaadoz       = EXCLUDED.nuovaadoz,
  daacquist       = EXCLUDED.daacquist,
  consigliato     = EXCLUDED.consigliato,
  import_scuola_id= COALESCE(old_adozioni.import_scuola_id, EXCLUDED.import_scuola_id),
  updated_at      = GREATEST(old_adozioni.updated_at, EXCLUDED.updated_at);

-- 2) Reset import_adozioni
TRUNCATE TABLE import_adozioni RESTART IDENTITY CASCADE;

-- 3) Deduplicate new_adozioni on the same unique key and refill import_adozioni
WITH deduplicated_new_adozioni AS (
  SELECT DISTINCT ON (
    anno_scolastico,
    codicescuola,
    annocorso,
    sezioneanno,
    combinazione,
    codiceisbn
  )
    codicescuola,
    annocorso,
    sezioneanno,
    tipogradoscuola,
    combinazione,
    disciplina,
    codiceisbn,
    autori,
    titolo,
    sottotitolo,
    volume,
    editore,
    prezzo,
    nuovaadoz,
    daacquist,
    consigliato,
    anno_scolastico,
    id
  FROM new_adozioni
  ORDER BY
    anno_scolastico,
    codicescuola,
    annocorso,
    sezioneanno,
    combinazione,
    codiceisbn,
    id DESC
)
INSERT INTO import_adozioni (
  "CODICESCUOLA",
  "ANNOCORSO",
  "SEZIONEANNO",
  "TIPOGRADOSCUOLA",
  "COMBINAZIONE",
  "DISCIPLINA",
  "CODICEISBN",
  "AUTORI",
  "TITOLO",
  "SOTTOTITOLO",
  "VOLUME",
  "EDITORE",
  "PREZZO",
  "NUOVAADOZ",
  "DAACQUIST",
  "CONSIGLIATO",
  anno_scolastico,
  created_at,
  updated_at
)
SELECT
  codicescuola   AS "CODICESCUOLA",
  annocorso      AS "ANNOCORSO",
  sezioneanno    AS "SEZIONEANNO",
  tipogradoscuola AS "TIPOGRADOSCUOLA",
  combinazione   AS "COMBINAZIONE",
  disciplina     AS "DISCIPLINA",
  codiceisbn     AS "CODICEISBN",
  autori         AS "AUTORI",
  titolo         AS "TITOLO",
  sottotitolo    AS "SOTTOTITOLO",
  volume         AS "VOLUME",
  editore        AS "EDITORE",
  prezzo         AS "PREZZO",
  nuovaadoz      AS "NUOVAADOZ",
  daacquist      AS "DAACQUIST",
  consigliato    AS "CONSIGLIATO",
  anno_scolastico,
  CURRENT_TIMESTAMP AS created_at,
  CURRENT_TIMESTAMP AS updated_at
FROM deduplicated_new_adozioni;

COMMIT;

-- Checks
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