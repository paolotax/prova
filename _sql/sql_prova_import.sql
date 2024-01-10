-- libri
select distinct
    "CODICEISBN" as codice_isbn,
    "AUTORI"     as autori,
    "TITOLO"     as titolo,
    "SOTTOTITOLO" as sottotitolo,
    "VOLUME"     as volume,
    "EDITORE"    as editore,
    "PREZZO"     as prezzo
from  import_adozioni;

-- editori
select distinct "EDITORE" as editore from import_adozioni;

-- discipline
select distinct
    "TIPOGRADOSCUOLA" as grado_scuola,
    "ANNOCORSO"       as anno_corso,
    "DISCIPLINA"      as disciplina
from import_adozioni order by "TIPOGRADOSCUOLA", "ANNOCORSO", "DISCIPLINA";

-- combinazioni
select distinct
    "TIPOGRADOSCUOLA" as grado_scuola,
    "COMBINAZIONE"    as combinazione
from import_adozioni ORDER BY "TIPOGRADOSCUOLA", "COMBINAZIONE";


-- zone
select distinct
    "AREAGEOGRAFICA" as area_geografica,
    "REGIONE"        as regione,
    "PROVINCIA"      as provincia,
    "DESCRIZIONECOMUNE" as comune,
    "CODICECOMUNESCUOLA" as codice_coumune_scuola
from import_scuole
order by area_geografica, regione, provincia, comune

-- tipi_scuole
select distinct
    import_scuole."DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA" as tipo_scuola,
    import_scuole."DESCRIZIONECARATTERISTICASCUOLA" as caratteristica_scuola,
    import_adozioni."TIPOGRADOSCUOLA" as grado_scuola
from import_scuole
left outer join import_adozioni on import_scuole."CODICESCUOLA" = import_adozioni."CODICESCUOLA"
order by tipo_scuola, caratteristica_scuola

