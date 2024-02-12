SELECT DISTINCT import_scuole."REGIONE"                                                                           AS regione,
                import_scuole."PROVINCIA"                                                                         AS provincia,
                import_adozioni."EDITORE"                                                                         AS editore,
                '144 antropologico'::text                                                                         AS mercato,
                count(1)
                OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA")                            AS in_provincia,
                count(1)
                OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE") AS dell_editore_in_provincia,
                round((count(1)
                       OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE")::double precision /
                       count(1)
                       OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA")::double precision *
                       100::double precision)::numeric,
                      2)                                                                                          AS percentuale_editore_in_provincia,
                round((count(1)
                       OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE")::double precision /
                       count(1)
                       OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA")::double precision *
                       100::double precision)::numeric, 2) - round(
                        (count(1) OVER (PARTITION BY import_adozioni."EDITORE")::double precision /
                         count(1) OVER ()::double precision * 100::double precision)::numeric,
                        2)                                                                                        AS differenza_media_nazionale,
                count(1) OVER (PARTITION BY import_adozioni."EDITORE")                                            AS dell_editore_in_italia,
                round((count(1) OVER (PARTITION BY import_adozioni."EDITORE")::double precision /
                       count(1) OVER ()::double precision * 100::double precision)::numeric,
                      2)                                                                                          AS percentuale_editore_in_italia,
                count(1)
                OVER (PARTITION BY import_scuole."REGIONE", import_adozioni."EDITORE")                            AS dell_editore_in_regione,
                round((count(1)
                       OVER (PARTITION BY import_scuole."REGIONE", import_adozioni."EDITORE")::double precision /
                       count(1) OVER (PARTITION BY import_scuole."REGIONE")::double precision *
                       100::double precision)::numeric,
                      2)                                                                                          AS percentuale_editore_in_regione
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text
WHERE (import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"::text = ANY
       (ARRAY ['SCUOLA PRIMARIA'::character varying::text, 'SCUOLA PRIMARIA NON STATALE'::character varying::text, 'ISTITUTO COMPRENSIVO'::character varying::text]))
  AND (import_adozioni."ANNOCORSO"::text = ANY (ARRAY ['1'::character varying::text, '4'::character varying::text]))
  AND (import_adozioni."DISCIPLINA"::text = ANY
       (ARRAY ['IL LIBRO DELLA PRIMA CLASSE'::character varying::text, 'SUSSIDIARIO DEI LINGUAGGI'::character varying::text, 'SUSSIDIARIO DELLE DISCIPLINE'::character varying::text, 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)'::character varying::text]))
ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA",
         (round((count(1)
                 OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."EDITORE")::double precision /
                 count(1) OVER (PARTITION BY import_scuole."REGIONE", import_scuole."PROVINCIA")::double precision *
                 100::double precision)::numeric, 2)) DESC;
