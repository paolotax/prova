SELECT DISTINCT import_scuole."AREAGEOGRAFICA"              AS area_geografica,
                import_scuole."REGIONE"                     AS regione,
                import_scuole."PROVINCIA"                   AS provincia,
                tipi_scuole.grado                           AS grado,
                import_adozioni."ANNOCORSO"                 AS classe,
                import_adozioni."DISCIPLINA"                AS disciplina,
                import_adozioni."CODICEISBN"                AS isbn,
                import_adozioni."TITOLO"                    AS titolo,
                import_adozioni."EDITORE"                   AS editore,
                import_adozioni."PREZZO"                    AS prezzo,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA") AS titolo_in_provincia,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."REGIONE")   AS titolo_in_regione,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN")                            AS titolo_in_italia,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA")                               AS mercato_in_provincia,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."REGIONE")                                 AS mercato_in_regione,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA")                                                          AS mercato_in_italia,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."PROVINCIA")       AS editore_in_provincia,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE", import_scuole."REGIONE")         AS editore_in_regione,
                count(1)
                OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."EDITORE")                                  AS editore_in_italia,
                round((count(1)
                       OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN", import_scuole."PROVINCIA")::double precision /
                       count(1)
                       OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_scuole."PROVINCIA")::double precision *
                       100::double precision)::numeric,
                      2)                                                                                                                                                     AS percentuale_titolo_provincia,
                round((count(1)
                       OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."CODICEISBN")::double precision /
                       count(1)
                       OVER (PARTITION BY tipi_scuole.grado, import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA")::double precision *
                       100::double precision)::numeric,
                      2)                                                                                                                                                     AS percentuale_titolo_italia
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text
    JOIN tipi_scuole ON import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" = tipi_scuole.tipo
WHERE tipi_scuole.grado = 'E'
ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA",
         import_adozioni."TITOLO";
