SELECT DISTINCT row_number() OVER (PARTITION BY true::boolean)::bigint   AS id,
                import_scuole."AREAGEOGRAFICA" AS area_geografica,
                import_scuole."REGIONE"        AS regione,
                import_scuole."PROVINCIA"      AS provincia,
                import_scuole."CODICESCUOLA"   AS codice_ministeriale,
                import_adozioni."ANNOCORSO"    AS classe,
                import_adozioni."SEZIONEANNO"  AS sezione,
                import_adozioni."COMBINAZIONE" AS combinazione,
                ARRAY_AGG(import_adozioni.id) AS import_adozioni_ids,
                import_scuole."ANNOSCOLASTICO" AS anno
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"  = import_scuole."CODICESCUOLA"
GROUP BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA", import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO", import_adozioni."COMBINAZIONE", anno
ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA",
         import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO",
         import_adozioni."COMBINAZIONE";
