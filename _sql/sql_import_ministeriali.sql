SELECT DISTINCT new_adozioni.codiceisbn AS codice_isbn,
       new_adozioni.titolo,
       editori.id AS editore_id,
       new_adozioni.annocorso as classe,
       new_adozioni.disciplina,
       COALESCE(TO_NUMBER(new_adozioni.prezzo, 'FM9G999G999D99S'), 0) AS prezzo_in_cents
FROM new_adozioni
INNER JOIN new_scuole ON new_adozioni.codicescuola = new_scuole.codice_scuola
INNER JOIN user_scuole ON new_scuole.import_scuola_id = user_scuole.import_scuola_id
INNER JOIN users ON user_scuole.user_id = users.id
INNER JOIN editori ON editori.editore = new_adozioni.editore
INNER JOIN mandati ON mandati.editore_id = editori.id AND mandati.user_id = users.id
WHERE
    new_adozioni.daacquist = 'Si'
AND
    users.id = {{user.id}}