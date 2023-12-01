SELECT DISTINCT 
                CONCAT(fornitore, '-', data_documento, '-', numero_documento) AS "id",
                fornitore,
                tipo_documento,
                numero_documento,
                data_documento,
                sum(quantita)                         AS quantita_totale,
                CASE
                    WHEN tipo_documento = 'Nota di accredito' THEN - totale_documento
                    ELSE totale_documento END         AS totale_documento,
                totale_documento - sum(importo_netto) AS "check"
FROM imports
GROUP BY fornitore, tipo_documento, numero_documento, data_documento, totale_documento
ORDER BY fornitore, data_documento, numero_documento, tipo_documento;
                