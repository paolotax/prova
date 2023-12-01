SELECT imports.codice_articolo,
       imports.descrizione,
       - sum(imports.quantita)      AS quantita_totale,
       - sum(imports.importo_netto) AS importo_netto_totale
FROM imports
WHERE imports.tipo_documento::text = 'Nota di accredito'::text
GROUP BY imports.codice_articolo, imports.descrizione
UNION ALL
SELECT imports.codice_articolo,
       imports.descrizione,
       sum(imports.quantita)      AS quantita_totale,
       sum(imports.importo_netto) AS importo_netto_totale
FROM imports
WHERE imports.tipo_documento::text <> 'Nota di accredito'::text
GROUP BY imports.codice_articolo, imports.descrizione
ORDER BY 1;