SELECT DISTINCT codice_articolo,
                descrizione,
                fornitore,
                sum(quantita)      AS quantita,
                sum(importo_netto) AS importo
FROM view_righe
WHERE codice_articolo IS NOT NULL
GROUP BY codice_articolo, descrizione, fornitore
ORDER BY codice_articolo;