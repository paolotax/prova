WITH P AS (
SELECT DISTINCT
    tipi_scuole.grado,
    new_adozioni.annocorso                    AS classe,
    SUBSTRING(new_adozioni.disciplina, 0, 29) AS disciplina,
    new_adozioni.codiceisbn,
    new_adozioni.titolo,
    new_adozioni.editore,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), new_adozioni.codiceisbn)
                                                AS titolo_in_italia,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29))
                                                AS mercato_in_italia,

    count(1)
    OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), new_adozioni.editore)
                                                AS editore_in_italia,

    round((count(1)
            OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29), new_adozioni.codiceisbn)::double precision /
            count(1)
            OVER (PARTITION BY tipi_scuole.grado, new_adozioni.annocorso, SUBSTRING(new_adozioni.disciplina, 0, 29))::double precision *
            100::double precision)::numeric, 2)
                                                AS percentuale_titolo_italia
FROM new_scuole
JOIN new_adozioni ON new_adozioni.codicescuola = new_scuole.codice_scuola
JOIN tipi_scuole ON new_scuole.tipo_scuola = tipi_scuole.tipo
WHERE tipi_scuole.grado = 'E'
AND (new_adozioni.annocorso = ANY
        (ARRAY ['1', '4']))
AND (new_adozioni.disciplina = ANY
        (ARRAY ['IL LIBRO DELLA PRIMA CLASSE',
            'SUSSIDIARIO DEI LINGUAGGI',
            'SUSSIDIARIO DELLE DISCIPLINE',
            'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO) ',
            'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)']))

ORDER BY classe, disciplina, titolo
)
SELECT classe, disciplina, editore, titolo, codiceisbn,
       titolo_in_italia,
       percentuale_titolo_italia,
       mercato_in_italia
FROM p
ORDER BY disciplina, titolo_in_italia DESC