
-- aggiorna import_scuola_id su new_scuole
UPDATE new_scuole SET import_scuola_id = import_scuole.id FROM import_scuole WHERE import_scuole."CODICESCUOLA" = new_scuole.codice_scuola


-- scuole in meno
SELECT import_scuole.*
FROM import_scuole
LEFT JOIN new_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
WHERE codice_scuola IS NULL;


-- adozioni in meno
WITH scu_m AS (
    SELECT DISTINCT import_scuole."CODICESCUOLA"
    FROM import_scuole
    LEFT JOIN new_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
    WHERE codice_scuola IS NULL
)
SELECT import_adozioni.*
FROM import_adozioni, scu_m
WHERE import_adozioni."CODICESCUOLA" = scu_m."CODICESCUOLA";


-- adozioni in meno (+ veloce)
SELECT import_adozioni.*
FROM import_adozioni
INNER JOIN import_scuole ON import_adozioni."CODICESCUOLA" = import_scuole."CODICESCUOLA"
LEFT JOIN new_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
WHERE codice_scuola IS NULL


-- scuole in piu
SELECT new_scuole.*
FROM new_scuole
LEFT JOIN import_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
WHERE import_scuole."CODICESCUOLA" IS NULL;

-- adozioni in piu
WITH n AS (
    SELECT DISTINCT new_scuole.codice_scuola
    FROM new_scuole
    LEFT JOIN import_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
    WHERE import_scuole."CODICESCUOLA" IS NULL
)
SELECT new_adozioni.*
FROM new_adozioni, n
WHERE n.codice_scuola = new_adozioni.codicescuola;


-- controllo totali scuole e adozioni
SELECT * FROM
        (SELECT COUNT(new_scuole.*) AS scuole_in_piu
            FROM new_scuole
            LEFT JOIN import_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
            WHERE import_scuole."CODICESCUOLA" IS NULL) AS a,

        (SELECT COUNT(import_scuole.*) AS scuole_in_meno
            FROM import_scuole
            LEFT JOIN new_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
         WHERE codice_scuola IS NULL) as b,

        (WITH n AS (
            SELECT DISTINCT new_scuole.codice_scuola
                FROM new_scuole
                LEFT JOIN import_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
                WHERE import_scuole."CODICESCUOLA" IS NULL
        )
        SELECT COUNT(new_adozioni.*) AS adozioni_in_piu
            FROM new_adozioni, n
            WHERE n.codice_scuola = new_adozioni.codicescuola) as c,

        (SELECT COUNT(import_adozioni.*) AS adozioni_in_meno
            FROM import_adozioni
            INNER JOIN import_scuole ON import_adozioni."CODICESCUOLA" = import_scuole."CODICESCUOLA"
            LEFT JOIN new_scuole ON import_scuole."CODICESCUOLA" = new_scuole.codice_scuola
            WHERE codice_scuola IS NULL) AS d;

