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

SELECT * FROM righe;



SELECT users.id, libri.titolo, libri.codice_isbn,
       (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 0), 0) -
       COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 0), 0)) as ordini,
       (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 1), 0) -
       COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 1), 0)) as vendite,
       (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 2), 0) -
       COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 2), 0)) as carichi
FROM righe
INNER JOIN libri ON righe.libro_id = libri.id
INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
INNER JOIN documenti ON documento_righe.documento_id = documenti.id
INNER JOIN causali ON documenti.causale_id = causali.id
INNER JOIN users ON users.id = documenti.user_id
GROUP BY 1, 2, 3
ORDER BY 2

 SELECT libri.id, libri.titolo, causali.causale, documenti.status, sum(righe.quantita) as quantita
  FROM libri
          JOIN righe ON righe.libro_id = libri.id
          JOIN documento_righe on righe.id = documento_righe.riga_id
          JOIN documenti on documento_righe.documento_id = documenti.id
          JOIN causali on documenti.causale_id = causali.id
          JOIN users on documenti.user_id = users.id
  WHERE users.id = 1
  GROUP BY 1, 2, 3, 4
  ORDER BY 2


