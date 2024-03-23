SELECT DISTINCT import_scuole."AREAGEOGRAFICA" AS area_geografica,
                import_scuole."REGIONE"        AS regione,
                import_scuole."PROVINCIA"      AS provincia,
                import_scuole."CODICESCUOLA"   AS codice_ministeriale,
                import_adozioni."ANNOCORSO"    AS classe,
                import_adozioni."SEZIONEANNO"  AS sezione,
                import_adozioni."COMBINAZIONE" AS combinazione,
                '2023'::text                   AS anno
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text
ORDER BY import_scuole."AREAGEOGRAFICA", import_scuole."REGIONE", import_scuole."PROVINCIA",
         import_scuole."CODICESCUOLA", import_adozioni."ANNOCORSO", import_adozioni."SEZIONEANNO",
         import_adozioni."COMBINAZIONE";