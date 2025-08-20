-- Script per aggiornare import_scuole con dati di new_scuole

-- 1. Prima verifichiamo quanti record nuovi ci sono
SELECT COUNT(*) as nuove_scuole
FROM new_scuole ns
WHERE NOT EXISTS (
    SELECT 1
    FROM import_scuole i
    WHERE i."CODICESCUOLA" = ns.codice_scuola
);

-- 2. Inseriamo le nuove scuole in import_scuole
INSERT INTO import_scuole (
    "ANNOSCOLASTICO",
    "AREAGEOGRAFICA",
    "REGIONE",
    "PROVINCIA",
    "CODICEISTITUTORIFERIMENTO",
    "DENOMINAZIONEISTITUTORIFERIMENTO",
    "CODICESCUOLA",
    "DENOMINAZIONESCUOLA",
    "INDIRIZZOSCUOLA",
    "CAPSCUOLA",
    "CODICECOMUNESCUOLA",
    "DESCRIZIONECOMUNE",
    "DESCRIZIONECARATTERISTICASCUOLA",
    "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
    "INDICAZIONESEDEDIRETTIVO",
    "INDICAZIONESEDEOMNICOMPRENSIVO",
    "INDIRIZZOEMAILSCUOLA",
    "INDIRIZZOPECSCUOLA",
    "SITOWEBSCUOLA",
    "SEDESCOLASTICA",
    created_at,
    updated_at
)
SELECT
    ns.anno_scolastico,
    ns.area_geografica,
    ns.regione,
    ns.provincia,
    ns.codice_istituto_riferimento,
    ns.denominazione_istituto_riferimento,
    ns.codice_scuola,
    ns.denominazione,
    ns.indirizzo,
    ns.cap,
    ns.codice_comune,
    ns.comune,
    ns.descrizione_caratteristica,
    ns.tipo_scuola,
    ns.indicazione_sede_direttivo,
    ns.indicazione_sede_omnicomprensivo,
    ns.email,
    ns.pec,
    ns.sito_web,
    ns.sede_scolastica,
    NOW() as created_at,
    NOW() as updated_at
FROM new_scuole ns
WHERE NOT EXISTS (
    SELECT 1
    FROM import_scuole i
    WHERE i."CODICESCUOLA" = ns.codice_scuola
);

-- 3. Aggiorniamo i record esistenti (se necessario)
UPDATE import_scuole
SET
    "ANNOSCOLASTICO" = ns.anno_scolastico,
    "AREAGEOGRAFICA" = ns.area_geografica,
    "REGIONE" = ns.regione,
    "PROVINCIA" = ns.provincia,
    "CODICEISTITUTORIFERIMENTO" = ns.codice_istituto_riferimento,
    "DENOMINAZIONEISTITUTORIFERIMENTO" = ns.denominazione_istituto_riferimento,
    "DENOMINAZIONESCUOLA" = ns.denominazione,
    "INDIRIZZOSCUOLA" = ns.indirizzo,
    "CAPSCUOLA" = ns.cap,
    "CODICECOMUNESCUOLA" = ns.codice_comune,
    "DESCRIZIONECOMUNE" = ns.comune,
    "DESCRIZIONECARATTERISTICASCUOLA" = ns.descrizione_caratteristica,
    "DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" = ns.tipo_scuola,
    "INDICAZIONESEDEDIRETTIVO" = ns.indicazione_sede_direttivo,
    "INDICAZIONESEDEOMNICOMPRENSIVO" = ns.indicazione_sede_omnicomprensivo,
    "INDIRIZZOEMAILSCUOLA" = ns.email,
    "INDIRIZZOPECSCUOLA" = ns.pec,
    "SITOWEBSCUOLA" = ns.sito_web,
    "SEDESCOLASTICA" = ns.sede_scolastica,
    updated_at = NOW()
FROM new_scuole ns
WHERE import_scuole."CODICESCUOLA" = ns.codice_scuola;

-- 4. Verifichiamo il risultato finale
SELECT
    COUNT(*) as totale_import_scuole,
    COUNT(DISTINCT "CODICESCUOLA") as scuole_distinte
FROM import_scuole;

-- 5. Verifichiamo le scuole che sono state aggiunte/aggiornate
SELECT
    "CODICESCUOLA",
    "DENOMINAZIONESCUOLA",
    "PROVINCIA",
    created_at,
    updated_at
FROM import_scuole
WHERE updated_at >= NOW() - INTERVAL '1 minute'
ORDER BY updated_at DESC;