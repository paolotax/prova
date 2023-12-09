SELECT DISTINCT codice_articolo,
                descrizione,
                sum(quantita)      AS giacenza,
                sum(importo_netto) AS valore
FROM view_righe
WHERE codice_articolo IS NOT NULL
GROUP BY codice_articolo, descrizione
ORDER BY codice_articolo;