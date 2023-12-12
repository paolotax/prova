SELECT DISTINCT 
                CONCAT(fornitore, '-', numero_documento, '-', data_documento) AS "id",
                fornitore,
                iva_fornitore,
                cliente,
                iva_cliente,                
                tipo_documento,
                numero_documento,
                data_documento,
                
                CASE
                    WHEN tipo_documento IN ('Nota di accredito', 'TD04')  THEN - sum(quantita)
                    ELSE sum(quantita) END            AS quantita_totale,
                
                CASE
                    WHEN tipo_documento IN ('Nota di accredito', 'TD04')  THEN - ROUND(sum(importo_netto * 100))
                    ELSE ROUND(sum(importo_netto * 100)) END       AS importo_netto_totale,
                
                CASE
                    WHEN tipo_documento IN ('Nota di accredito', 'TD04')  THEN - ROUND(totale_documento * 100)
                    ELSE ROUND(totale_documento * 100) END         AS totale_documento,
                
                CASE 
                    WHEN iva_fornitore = '04155820378' then 'c.vendite'
                    ELSE 'c.acquisti' END AS conto,
                ROUND(totale_documento * 100) - ROUND(sum(importo_netto) * 100) AS "check"
FROM imports
GROUP BY fornitore, iva_fornitore, cliente, iva_cliente, tipo_documento, numero_documento, data_documento, totale_documento
ORDER BY fornitore, data_documento DESC, numero_documento, tipo_documento;
                