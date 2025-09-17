SELECT 
  EXTRACT(YEAR FROM documenti.data_documento)::integer as anno,
  editori.gruppo,
  libri.categoria,
  COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1), 0) - 
  COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0), 0) as totale_copie_vendute,
  COALESCE(SUM((righe.prezzo_cents - (righe.prezzo_cents * righe.sconto / 100)) * righe.quantita) FILTER (WHERE causali.movimento = 1), 0) / 100.0 - 
  COALESCE(SUM((righe.prezzo_cents - (righe.prezzo_cents * righe.sconto / 100)) * righe.quantita) FILTER (WHERE causali.movimento = 0), 0) / 100.0 as totale_vendite_euro
FROM righe
INNER JOIN libri ON righe.libro_id = libri.id
INNER JOIN editori ON libri.editore_id = editori.id
INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
INNER JOIN documenti ON documento_righe.documento_id = documenti.id
INNER JOIN causali ON documenti.causale_id = causali.id
INNER JOIN users ON users.id = documenti.user_id
WHERE users.id = :user_id
  AND causali.magazzino = 'vendita'
GROUP BY EXTRACT(YEAR FROM documenti.data_documento)::integer, editori.gruppo, libri.categoria
ORDER BY anno, editori.gruppo, libri.categoria;

