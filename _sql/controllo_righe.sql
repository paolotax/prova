select *
FROM righe
INNER JOIN libri ON righe.libro_id = libri.id
INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
INNER JOIN documenti ON documento_righe.documento_id = documenti.id


DELETE FROM righe WHERE righe.id IN (SELECT righe.id FROM righe
LEFT JOIN documento_righe ON documento_righe.riga_id = righe.id
WHERE documento_righe.riga_id is null)

SELECT righe.id FROM righe
LEFT JOIN documento_righe ON documento_righe.riga_id = righe.id
WHERE documento_righe.riga_id is null

SELECT * FROM righe