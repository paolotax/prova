-- Query per individuare le tue scuole con mie adozioni che non hanno una tappa collegata al giro "Kit 2025"
-- 
-- Sostituire :user_id con il tuo ID utente effettivo

WITH mie_scuole_con_adozioni AS (
    -- Scuole dell'utente che hanno adozioni per gli editori che rappresento
    SELECT DISTINCT 
        is_scuola.id as scuola_id,
        is_scuola."CODICESCUOLA",
        is_scuola."DENOMINAZIONESCUOLA",
        is_scuola."DESCRIZIONECOMUNE",
        is_scuola."PROVINCIA",
        COUNT(ia.id) as numero_adozioni
    FROM user_scuole us
        INNER JOIN import_scuole is_scuola ON us.import_scuola_id = is_scuola.id
        INNER JOIN import_adozioni ia ON ia."CODICESCUOLA" = is_scuola."CODICESCUOLA"
        INNER JOIN editori e ON ia."EDITORE" = e.editore
        INNER JOIN mandati m ON e.id = m.editore_id
    WHERE us.user_id = :user_id
        AND m.user_id = :user_id
        AND ia."DAACQUIST" = 'Si'
    GROUP BY 
        is_scuola.id, is_scuola."CODICESCUOLA", is_scuola."DENOMINAZIONESCUOLA",
        is_scuola."DESCRIZIONECOMUNE", is_scuola."PROVINCIA"
), scuole_con_tappa_kit_2025 AS (
    -- Scuole che hanno già una tappa collegata al giro "Kit 2025"
    SELECT DISTINCT t.tappable_id as scuola_id
    FROM tappe t
        INNER JOIN tappa_giri tg ON t.id = tg.tappa_id
        INNER JOIN giri g ON tg.giro_id = g.id
    WHERE t.tappable_type = 'ImportScuola'
        AND t.user_id = :user_id
        AND g.user_id = :user_id
        AND g.titolo = 'Kit 2025'
)
-- Risultato finale: mie scuole con adozioni che NON hanno tappa Kit 2025
SELECT 
    ROW_NUMBER() OVER (ORDER BY msca."PROVINCIA", msca."DESCRIZIONECOMUNE", msca."DENOMINAZIONESCUOLA") as numero,
    msca."CODICESCUOLA",
    msca."DENOMINAZIONESCUOLA",
    msca."DESCRIZIONECOMUNE",
    msca."PROVINCIA",
    msca.numero_adozioni as sezioni
FROM mie_scuole_con_adozioni msca
LEFT JOIN scuole_con_tappa_kit_2025 sctk ON msca.scuola_id = sctk.scuola_id
WHERE sctk.scuola_id IS NULL
ORDER BY 
    msca."PROVINCIA", 
    msca."DESCRIZIONECOMUNE", 
    msca."DENOMINAZIONESCUOLA";
