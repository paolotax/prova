with uscite as (
    SELECT libri.id, libri.titolo, sum(righe.quantita) as quantita
    FROM libri
             JOIN righe ON righe.libro_id = libri.id
             JOIN documento_righe on righe.id = documento_righe.riga_id
             JOIN documenti on documento_righe.documento_id = documenti.id
             JOIN causali on documenti.causale_id = causali.id
    WHERE causali.movimento = 1
    GROUP BY libri.id, libri.titolo
    ORDER BY libri.titolo),
entrate as (
    SELECT libri.id, libri.titolo, sum(righe.quantita) as quantita
    FROM libri
             JOIN righe ON righe.libro_id = libri.id
             JOIN documento_righe on righe.id = documento_righe.riga_id
             JOIN documenti on documento_righe.documento_id = documenti.id
             JOIN causali on documenti.causale_id = causali.id
    WHERE causali.movimento = 0
    GROUP BY libri.id, libri.titolo
    ORDER BY libri.titolo
)
SELECT uscite.id, uscite.titolo, uscite.quantita - COALESCE(entrate.quantita, 0) as uscite
FROM uscite
LEFT JOIN entrate ON entrate.id = uscite.id



