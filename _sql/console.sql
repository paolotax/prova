-- nr_scuole e nr_sezioni per editore elementari
SELECT "import_adozioni"."EDITORE",
       COUNT(DISTINCT "import_scuole"."id") nr_scuole,
       COUNT("import_adozioni"."id") nr_sezioni
FROM import_scuole, import_adozioni
WHERE "import_scuole"."CODICESCUOLA" = "import_adozioni"."CODICESCUOLA"
AND "import_adozioni"."TIPOGRADOSCUOLA" = 'EE'
AND "import_adozioni"."DAACQUIST" = 'Si'
GROUP BY "import_adozioni"."EDITORE"
ORDER BY nr_sezioni DESC;

-- nr_scuole nr_adozioni per provincia
SELECT
    "import_scuole"."REGIONE", 
    "import_scuole"."PROVINCIA", 
    "EDITORE", count(DISTINCT "import_scuole"."id") nr_scuole, 
    count("import_adozioni". "id") nr_adozioni 
FROM "import_scuole" 
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA" 
WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO') 
GROUP BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "EDITORE"


-- classifica adozioni per disciplina, editore, anno corso
SELECT
    "import_adozioni"."TIPOGRADOSCUOLA",
    "import_adozioni"."ANNOCORSO",
    "import_adozioni"."DISCIPLINA",
    "import_adozioni"."EDITORE",

    COUNT("import_adozioni"."id") nr_sezioni

FROM "import_adozioni"
INNER JOIN "import_scuole" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"
INNER JOIN "user_scuole" ON "import_scuole"."id" = "user_scuole"."import_scuola_id"

WHERE "user_scuole"."user_id" = 1
GROUP BY
    "import_adozioni"."TIPOGRADOSCUOLA",
    "import_adozioni"."ANNOCORSO",
    "import_adozioni"."DISCIPLINA",
    "import_adozioni"."EDITORE"
ORDER BY
    "import_adozioni"."TIPOGRADOSCUOLA",
    "import_adozioni"."ANNOCORSO",
    "import_adozioni"."DISCIPLINA",
    nr_sezioni DESC;

-- classifica adozioni elementari per provincia ed editore
SELECT
    "import_scuole"."REGIONE",
    "import_scuole"."PROVINCIA",
    "import_adozioni"."EDITORE",
    count(DISTINCT "import_scuole"."id") nr_scuole,
    count("import_adozioni". "id") nr_adozioni
FROM "import_scuole"
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"
WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO')
GROUP BY "import_scuole"."REGIONE",
         "import_scuole"."PROVINCIA",
         "import_adozioni"."EDITORE"
ORDER BY "import_scuole"."REGIONE",
         "import_scuole"."PROVINCIA",
         nr_adozioni DESC;

-- classifica_elementari_provincia_materia_editore
SELECT DISTINCT
    "import_scuole"."REGIONE" regione,
    "import_scuole"."PROVINCIA" provincia,
    "import_adozioni"."ANNOCORSO" classe,
    "import_adozioni"."DISCIPLINA" disciplina,
    "import_adozioni"."EDITORE" editore,
    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."DISCIPLINA", "import_adozioni"."ANNOCORSO") in_provincia,
    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."DISCIPLINA", "import_adozioni"."ANNOCORSO", "import_adozioni"."EDITORE") dell_editore,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."DISCIPLINA", "import_adozioni"."ANNOCORSO", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."DISCIPLINA", "import_adozioni"."ANNOCORSO")::float) * 100)::numeric, 2) percentuale

FROM "import_scuole"
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"
WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO')
ORDER BY
    regione, provincia, classe, disciplina, percentuale DESC;


SELECT * FROM classifica_elementari_provincia_materia_editore
WHERE classe = '1' AND disciplina = 'RELIGIONE'
AND editore = 'GIUNTI SCUOLA' ORDER BY  percentuale DESC


--religione_1_4
SELECT DISTINCT provincia, disciplina, editore, sum(dell_editore) sezioni, ROUND(AVG(percentuale)::numeric, 2) percentuale
  FROM classifica_elementari_provincia_materia_editore
WHERE classe IN ( '1', '4')
AND disciplina IN ( 'RELIGIONE' )
GROUP BY provincia, disciplina, editore
 ORDER BY  provincia, percentuale DESC;

--1_4_4a
SELECT DISTINCT provincia, disciplina, editore, sum(dell_editore) sezioni, ROUND(AVG(percentuale)::numeric, 2) percentuale
  FROM classifica_elementari_provincia_materia_editore
WHERE classe IN ( '1', '4')
AND disciplina IN ( 'IL LIBRO DELLA PRIMA CLASSE', 'SUSSIDIARIO DEI LINGUAGGI', 'SUSSIDIARIO DELLE DISCIPLINE' )
GROUP BY provincia, disciplina, editore
 ORDER BY  provincia, editore, percentuale DESC;


-- 144 antropologico editore
SELECT DISTINCT
    "import_scuole"."REGIONE" regione,
    "import_scuole"."PROVINCIA" provincia,
    '144 antropologico' mercato,
    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA") in_provincia,
    "import_adozioni"."EDITORE" editore,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE") dell_editore_in_provincia,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2) percentuale_editore_in_provincia,

    (ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2))
    - (ROUND(((COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2)) differenza_media_nazionale,

    COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE") dell_editore_in_italia,
    ROUND(((COUNT(1) OVER (PARTITION BY  "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2) percentuale_editore_in_italia,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE") dell_editore_in_regione,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE")::float) * 100)::numeric, 2) percentuale_editore_in_regione

FROM "import_scuole"
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"

WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO')


AND "import_adozioni"."ANNOCORSO" IN ('1', '4')
AND "import_adozioni"."DISCIPLINA" IN ('IL LIBRO DELLA PRIMA CLASSE', 'SUSSIDIARIO DEI LINGUAGGI', 'SUSSIDIARIO DELLE DISCIPLINE', 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)')



ORDER BY
    regione, provincia, percentuale_editore_in_provincia DESC;



SELECT DISTINCT
    "import_scuole"."REGIONE" regione,
    "import_scuole"."PROVINCIA" provincia,
    '144 scientifico' mercato,
    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA") in_provincia,
    "import_adozioni"."EDITORE" editore,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE") dell_editore_in_provincia,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2) percentuale_editore_in_provincia,

    (ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2))
    - (ROUND(((COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2)) differenza_media_nazionale,

    COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE") dell_editore_in_italia,
    ROUND(((COUNT(1) OVER (PARTITION BY  "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2) percentuale_editore_in_italia,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE") dell_editore_in_regione,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE")::float) * 100)::numeric, 2) percentuale_editore_in_regione

FROM "import_scuole"
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"

WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO')


AND "import_adozioni"."ANNOCORSO" IN ('1', '4')
AND "import_adozioni"."DISCIPLINA" IN ('IL LIBRO DELLA PRIMA CLASSE', 'SUSSIDIARIO DEI LINGUAGGI', 'SUSSIDIARIO DELLE DISCIPLINE', 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)')



ORDER BY
    regione, provincia, percentuale_editore_in_provincia DESC;





------  final
SELECT DISTINCT import_scuole."AREAGEOGRAFICA"                                                                    AS area_geografica,
                import_scuole."REGIONE"                                                                           AS regione,
                import_scuole."PROVINCIA"                                                                         AS provincia,
                SUBSTR(import_adozioni."TIPOGRADOSCUOLA", 1, 1)                                                   AS grado,
                import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"                                         AS tipo,
                import_adozioni."ANNOCORSO"                                                                       AS classe,
                import_adozioni."DISCIPLINA"                                                                      AS disciplina,
                import_adozioni."CODICEISBN"                                                                      AS isbn,
                import_adozioni."TITOLO"                                                                          AS titolo,
                import_adozioni."EDITORE"                                                                         AS editore,
                import_adozioni."PREZZO"                                                                          AS prezzo,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."CODICEISBN",
                                   import_scuole."PROVINCIA")                                        AS titolo_in_provincia,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."CODICEISBN",
                                   import_scuole."REGIONE")                                          AS titolo_in_regione,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."CODICEISBN")                                      AS titolo_in_italia,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."PROVINCIA")                                      AS mercato_in_provincia,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."REGIONE")                                        AS mercato_in_regione,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA")                                   AS mercato_in_italia,


                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."EDITORE",
                                   import_scuole."PROVINCIA")                                        AS editore_in_provincia,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."EDITORE",
                                   import_scuole."REGIONE")                                          AS editore_in_regione,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."EDITORE" )                                       AS editore_in_italia,







                round((count(1)
                       OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."CODICEISBN",
                                   import_scuole."PROVINCIA")::double precision /
                       count(1)
                       OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."PROVINCIA")::double precision
                                          * 100::double precision)::numeric, 2)                       AS percentuale_titolo_provincia,

                round((count(1)
                       OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_adozioni."CODICEISBN")::double precision /
                       count(1)
                       OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA")::double precision
                                          * 100::double precision)::numeric, 2)                       AS percentuale_titolo_italia

FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text


ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA", import_adozioni."TITOLO";







-- mercato superiori
SELECT DISTINCT 'superiori'                                                                                       AS grado,
                import_scuole."AREAGEOGRAFICA"                                                                    AS area_geografica,
                import_scuole."REGIONE"                                                                           AS regione,
                import_scuole."PROVINCIA"                                                                         AS provincia,
                import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA"                                         AS tipo,
                import_adozioni."ANNOCORSO"                                                                       AS classe,
                import_adozioni."DISCIPLINA"                                                                      AS disciplina,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."PROVINCIA")                                      AS mercato_in_provincia,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."REGIONE")                                        AS mercato_in_regione,

                count(1)
                OVER (PARTITION BY import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA",
                                   import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA")                                   AS mercato_in_italia
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text

WHERE import_adozioni."TIPOGRADOSCUOLA" NOT IN ('EE', 'MM')

ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA";


-- classi_in_italia
SELECT DISTINCT import_scuole."AREAGEOGRAFICA"              AS area_geografica,
                import_scuole."REGIONE"                     AS regione,
                import_scuole."PROVINCIA"                   AS provincia,
                import_scuole."CODICESCUOLA"                AS codice_ministeriale,
                import_adozioni."ANNOCORSO"                 AS classe,
                import_adozioni."SEZIONEANNO"               AS sezione,
                import_adozioni."COMBINAZIONE"              AS combinazione,
                '2023'                                      AS anno
FROM import_scuole
JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text
ORDER BY area_geografica, regione, provincia, codice_ministeriale, classe, sezione, combinazione

create materialized view classi_2023 as
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

CREATE UNIQUE INDEX classi_2023_primary_index
        ON classi_2023 (codice_ministeriale, classe, sezione, combinazione);

CREATE INDEX classi_2023_codice_ministeriale_index
        ON classi_2023 (codice_ministeriale);

CREATE INDEX classi_2023_provincia_index
        ON classi_2023 (provincia);

alter materialized view classi_2023 owner to paolotax;







-- mercato elementari
SELECT DISTINCT 'elementari'                                                                                      AS grado,
                import_scuole."AREAGEOGRAFICA"                                                                    AS area_geografica,
                import_scuole."REGIONE"                                                                           AS regione,
                import_scuole."PROVINCIA"                                                                         AS provincia,
                import_adozioni."ANNOCORSO"                                                                       AS classe,
                import_adozioni."DISCIPLINA"                                                                      AS disciplina,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."PROVINCIA")                                      AS mercato_in_provincia,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."REGIONE")                                        AS mercato_in_regione,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA")                                   AS mercato_in_italia
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text

WHERE import_adozioni."TIPOGRADOSCUOLA" =  'EE'

ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA";





-- mercato medie
SELECT DISTINCT 'medie'                                                                                      AS grado,
                import_scuole."AREAGEOGRAFICA"                                                                    AS area_geografica,
                import_scuole."REGIONE"                                                                           AS regione,
                import_scuole."PROVINCIA"                                                                         AS provincia,
                import_adozioni."ANNOCORSO"                                                                       AS classe,
                import_adozioni."DISCIPLINA"                                                                      AS disciplina,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."PROVINCIA")                                      AS mercato_in_provincia,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA",
                                   import_scuole."REGIONE")                                        AS mercato_in_regione,

                count(1)
                OVER (PARTITION BY import_adozioni."ANNOCORSO",
                                   import_adozioni."DISCIPLINA")                                   AS mercato_in_italia
FROM import_scuole
         JOIN import_adozioni ON import_adozioni."CODICESCUOLA"::text = import_scuole."CODICESCUOLA"::text

WHERE import_adozioni."TIPOGRADOSCUOLA" =  'MM'

ORDER BY import_scuole."REGIONE", import_scuole."PROVINCIA", import_adozioni."ANNOCORSO", import_adozioni."DISCIPLINA";
















SELECT DISTINCT
provincia, editore,
sum(distinct editore_in_provincia) as editore_in_provincia,

(select(0) from (select  sum(distinct mercato_in_provincia)
from prima_quarta_quarta_scientifico B where provincia = B.provincia group by provincia) as foo),

RANK() OVER (PARTITION BY provincia ORDER BY sum(distinct editore_in_provincia) DESC )
FROM prima_quarta_quarta_scientifico


GROUP BY provincia, editore
ORDER BY provincia, editore_in_provincia DESC


select provincia FROM (select  sum(distinct mercato_in_provincia)
from prima_quarta_quarta_scientifico group by provincia);

SELECT DISTINCT provincia, avg(mercato_in_provincia) * 4, sum(titolo_in_provincia), avg(titolo_in_italia) * 4 FROM aggrega_adozioni
WHERE editore = 'GIUNTI SCUOLA'
  AND classe IN ('1', '4')
  AND disciplina IN ('IL LIBRO DELLA PRIMA CLASSE',
                     'SUSSIDIARIO DEI LINGUAGGI',
                     'SUSSIDIARIO DELLE DISCIPLINE',
                     'SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)')
GROUP BY provincia
ORDER BY provincia








SELECT DISTINCT
    "import_scuole"."REGIONE" regione,
    "import_scuole"."PROVINCIA" provincia,
    "import_adozioni"."EDITORE" editore,
    '144 antropologico' mercato,
    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA") in_provincia,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE") dell_editore_in_provincia,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2) percentuale_editore_in_provincia,

    (ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_scuole"."PROVINCIA")::float) * 100)::numeric, 2))
    - (ROUND(((COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2)) differenza_media_nazionale,

    COUNT(1) OVER (PARTITION BY "import_adozioni"."EDITORE") dell_editore_in_italia,
    ROUND(((COUNT(1) OVER (PARTITION BY  "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER ()) * 100)::numeric, 2) percentuale_editore_in_italia,

    COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE") dell_editore_in_regione,
    ROUND(((COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE", "import_adozioni"."EDITORE"))::float
        / (COUNT(1) OVER (PARTITION BY "import_scuole"."REGIONE")::float) * 100)::numeric, 2)
 percentuale_editore_in_regione

FROM "import_scuole"
    INNER JOIN "import_adozioni" ON "import_adozioni"."CODICESCUOLA" = "import_scuole"."CODICESCUOLA"

WHERE "import_scuole"."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" IN ('SCUOLA PRIMARIA', 'SCUOLA PRIMARIA NON STATALE', 'ISTITUTO COMPRENSIVO')


AND "import_adozioni"."ANNOCORSO" IN ('1', '4')
AND "import_adozioni"."DISCIPLINA" IN ('IL LIBRO DELLA PRIMA CLASSE', 'SUSSIDIARIO DEI LINGUAGGI', 'SUSSIDIARIO DELLE DISCIPLINE', 'SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)')



ORDER BY
    regione, provincia, percentuale_editore_in_provincia DESC;



SELECT DISTINCT regione,
                provincia,
                editore,
                RANK() OVER (PARTITION BY provincia ORDER BY dell_editore_in_provincia DESC),
                dell_editore_in_provincia,
                percentuale_editore_in_provincia,
                percentuale_editore_in_italia,
                differenza_media_nazionale

FROM view_adozioni144ant_editori
ORDER BY
    regione, provincia, RANK() OVER (PARTITION BY provincia ORDER BY dell_editore_in_provincia DESC);







SELECT DISTINCT regione, provincia, editore, in_provincia

FROM view_adozioni144ant_editori
ORDER BY
    regione, provincia, in_provincia DESC