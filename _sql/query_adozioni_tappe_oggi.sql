-- Query per ottenere il totale delle adozioni per titolo 
-- nelle scuole in cui ho una tappa DOMANI
-- SOLO per gli editori che l'utente rappresenta

WITH sezioni_raggruppate AS (
    SELECT 
        ia."TITOLO",
        ia."CODICEISBN", 
        ia."EDITORE",
        ia."DISCIPLINA",
        is_scuola."DENOMINAZIONESCUOLA",
        is_scuola.id as scuola_id,
        ia."ANNOCORSO",
        STRING_AGG(DISTINCT ia."SEZIONEANNO" ORDER BY ia."SEZIONEANNO", '') as sezioni_concatenate,
        COUNT(ia.id) as adozioni_per_classe
    FROM import_adozioni ia
        INNER JOIN import_scuole is_scuola ON ia."CODICESCUOLA" = is_scuola."CODICESCUOLA"
        INNER JOIN editori e ON ia."EDITORE" = e.editore
        INNER JOIN mandati m ON e.id = m.editore_id
        INNER JOIN tappe t ON (
            t.tappable_type = 'ImportScuola'
            AND t.tappable_id = is_scuola.id
            AND t.data_tappa = CURRENT_DATE
            AND t.user_id = 1
        )
    WHERE m.user_id = 1 AND ia."DAACQUIST" = 'Si'
    GROUP BY 
        ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA",
        is_scuola."DENOMINAZIONESCUOLA", is_scuola.id, ia."ANNOCORSO"
), saggi_per_adozione AS (
    SELECT 
        ia."TITOLO",
        ia."CODICEISBN",
        ia."EDITORE", 
        ia."DISCIPLINA",
        is_scuola."DENOMINAZIONESCUOLA",
        ia."ANNOCORSO",
        ia."SEZIONEANNO",
        COUNT(a.id) as numero_saggi
    FROM appunti a
        INNER JOIN import_adozioni ia ON a.import_adozione_id = ia.id
        INNER JOIN import_scuole is_scuola ON ia."CODICESCUOLA" = is_scuola."CODICESCUOLA"
        INNER JOIN tappe t ON (
            t.tappable_type = 'ImportScuola'
            AND t.tappable_id = is_scuola.id
            AND t.data_tappa = CURRENT_DATE
            AND t.user_id = 1
        )
    WHERE a.nome = 'saggio' AND a.user_id = 1
    GROUP BY ia."TITOLO", ia."CODICEISBN", ia."EDITORE", ia."DISCIPLINA", 
             is_scuola."DENOMINAZIONESCUOLA", ia."ANNOCORSO", ia."SEZIONEANNO"
)
SELECT
    SUM(sr.adozioni_per_classe) as numero_adozioni,
    sr."TITOLO" as titolo,
    sr."CODICEISBN" as codice_isbn,
    sr."EDITORE" as editore,
    sr."DISCIPLINA" as disciplina,
    STRING_AGG(DISTINCT sr."DENOMINAZIONESCUOLA", ', ') as scuole,
    STRING_AGG(DISTINCT 
        CONCAT(sr."DENOMINAZIONESCUOLA", ', ', sr."ANNOCORSO", ' ', sr.sezioni_concatenate,
               CASE 
                   WHEN COALESCE(SUM(spa.numero_saggi), 0) > 0 THEN CONCAT('(', SUM(spa.numero_saggi), ')')
                   ELSE ''
               END), 
        '; ') as classi
FROM sezioni_raggruppate sr
LEFT JOIN saggi_per_adozione spa ON (
    sr."TITOLO" = spa."TITOLO"
    AND sr."CODICEISBN" = spa."CODICEISBN"
    AND sr."EDITORE" = spa."EDITORE"
    AND sr."DISCIPLINA" = spa."DISCIPLINA"
    AND sr."DENOMINAZIONESCUOLA" = spa."DENOMINAZIONESCUOLA"
    AND sr."ANNOCORSO" = spa."ANNOCORSO"
)
GROUP BY
    sr."TITOLO",
    sr."CODICEISBN",
    sr."EDITORE",
    sr."DISCIPLINA"
ORDER BY
    sr."EDITORE",
    sr."DISCIPLINA",
    sr."TITOLO";


-- # Versione più semplice usando la relazione mie_adozioni già definita nel modello User:
-- current_user.mie_adozioni
--   .joins(:import_scuola)
--   .joins("INNER JOIN tappe ON tappe.tappable_type = 'ImportScuola' AND tappe.tappable_id = import_scuole.id")
--   .where("tappe.data_tappa = ? AND tappe.user_id = ?", Date.tomorrow, current_user.id)
--   .where("import_adozioni.\"DAACQUIST\" = 'Si'")
--   .group("import_adozioni.\"TITOLO\", import_adozioni.\"CODICEISBN\", import_adozioni.\"EDITORE\", import_adozioni.\"DISCIPLINA\"")
--   .select(
--     "import_adozioni.\"TITOLO\" as titolo",
--     "import_adozioni.\"CODICEISBN\" as codice_isbn", 
--     "import_adozioni.\"EDITORE\" as editore",
--     "import_adozioni.\"DISCIPLINA\" as disciplina",
--     "COUNT(import_adozioni.id) as numero_adozioni"
--   )
--   .order("numero_adozioni DESC, titolo")
