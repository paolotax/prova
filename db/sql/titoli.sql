WITH P AS (
SELECT DISTINCT
    tipi_scuole.grado,
    new_adozioni.annocorso                    AS classe,
    SUBSTRING(new_adozioni.disciplina, 0, 29) AS disciplina,
    SUBSTRING(new_adozioni.titolo, 0, 15)     AS titolo,
    new_adozioni.editore,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), SUBSTRING(new_adozioni.titolo, 0, 15))
                                                AS titolo_in_italia,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29))
                                                AS mercato_in_italia,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), new_adozioni.editore)
                                                AS editore_in_italia,

    round((count(1)
            OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), SUBSTRING(new_adozioni.titolo, 0, 15))::double precision /
            count(1)
            OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29))::double precision *
            100::double precision)::numeric, 2)
                                                AS percentuale_titolo_italia
FROM new_scuole
JOIN new_adozioni ON new_adozioni.codicescuola = new_scuole.codice_scuola::text
JOIN tipi_scuole ON new_scuole.tipo_scuola::text = tipi_scuole.tipo::text
WHERE tipi_scuole.grado::text = 'E'::text
AND (new_adozioni.annocorso = ANY
        (ARRAY ['1'::character varying::text, '4'::character varying::text]))
AND (new_adozioni.disciplina::text = ANY
        (ARRAY ['IL LIBRO DELLA PRIMA CLASSE'::character varying::text,
            'SUSSIDIARIO DEI LINGUAGGI'::character varying::text,
            'SUSSIDIARIO DELLE DISCIPLINE'::character varying::text,
            'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO) '::character varying::text]))

ORDER BY classe, disciplina, titolo
)
SELECT classe, disciplina, editore, titolo,

       titolo_in_italia,
       percentuale_titolo_italia,
       mercato_in_italia

FROM p

ORDER BY disciplina, titolo_in_italia DESC