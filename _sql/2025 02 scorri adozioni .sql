-- Script per trasferire dati tra tabelle adozioni (con JOIN per import_scuola_id)
-- Data: 2025-01-19

BEGIN;

-- 1. Copia tutti i record da import_adozioni a old_adozioni con JOIN per import_scuola_id
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
    ia."CODICESCUOLA" as codicescuola,
    ia."ANNOCORSO" as annocorso,
    ia."SEZIONEANNO" as sezioneanno,
    ia."TIPOGRADOSCUOLA" as tipogradoscuola,
    ia."COMBINAZIONE" as combinazione,
    ia."DISCIPLINA" as disciplina,
    ia."CODICEISBN" as codiceisbn,
    ia."AUTORI" as autori,
    ia."TITOLO" as titolo,
    ia."SOTTOTITOLO" as sottotitolo,
    ia."VOLUME" as volume,
    ia."EDITORE" as editore,
    ia."PREZZO" as prezzo,
    ia."NUOVAADOZ" as nuovaadoz,
    ia."DAACQUIST" as daacquist,
    ia."CONSIGLIATO" as consigliato,
    ia.anno_scolastico,
    iscuole.id as import_scuola_id,
    ia.created_at,
    ia.updated_at
FROM import_adozioni ia
LEFT JOIN import_scuole iscuole ON ia."CODICESCUOLA" = iscuole."CODICESCUOLA";

-- 2. Svuota la tabella import_adozioni
TRUNCATE TABLE import_adozioni RESTART IDENTITY CASCADE;

-- 3. Prima identifico e rimuovo i duplicati da new_adozioni usando una CTE
WITH deduplicated_new_adozioni AS (
    SELECT DISTINCT ON (
        codicescuola,
        annocorso,
        sezioneanno,
        tipogradoscuola,
        combinazione,
        codiceisbn,
        nuovaadoz,
        daacquist,
        consigliato
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
        anno_scolastico
    FROM new_adozioni
    ORDER BY
        codicescuola,
        annocorso,
        sezioneanno,
        tipogradoscuola,
        combinazione,
        codiceisbn,
        nuovaadoz,
        daacquist,
        consigliato,
        id -- Prende il primo record per ogni gruppo di duplicati
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
    codicescuola as "CODICESCUOLA",
    annocorso as "ANNOCORSO",
    sezioneanno as "SEZIONEANNO",
    tipogradoscuola as "TIPOGRADOSCUOLA",
    combinazione as "COMBINAZIONE",
    disciplina as "DISCIPLINA",
    codiceisbn as "CODICEISBN",
    autori as "AUTORI",
    titolo as "TITOLO",
    sottotitolo as "SOTTOTITOLO",
    volume as "VOLUME",
    editore as "EDITORE",
    prezzo as "PREZZO",
    nuovaadoz as "NUOVAADOZ",
    daacquist as "DAACQUIST",
    consigliato as "CONSIGLIATO",
    anno_scolastico,
    CURRENT_TIMESTAMP as created_at,
    CURRENT_TIMESTAMP as updated_at
FROM deduplicated_new_adozioni;

COMMIT;

-- Verifica dei risultati
SELECT 'old_adozioni' as tabella, COUNT(*) as record_count FROM old_adozioni
UNION ALL
SELECT 'import_adozioni' as tabella, COUNT(*) as record_count FROM import_adozioni
UNION ALL
SELECT 'new_adozioni' as tabella, COUNT(*) as record_count FROM new_adozioni
UNION ALL
SELECT 'duplicati_in_new_adozioni' as tabella,
       (SELECT COUNT(*) FROM new_adozioni) -
       (SELECT COUNT(DISTINCT (codicescuola, annocorso, sezioneanno, tipogradoscuola, combinazione, codiceisbn, nuovaadoz, daacquist, consigliato)) FROM new_adozioni) as record_count;

-- Verifica che il JOIN abbia funzionato
SELECT
    'scuole_matchate' as descrizione,
    COUNT(distinct codicescuola) as count
FROM old_adozioni
WHERE import_scuola_id IS NOT NULL
UNION ALL
SELECT
    'scuole_non_matchate' as descrizione,
    COUNT(distinct codicescuola) as count
FROM old_adozioni
WHERE import_scuola_id IS NULL;