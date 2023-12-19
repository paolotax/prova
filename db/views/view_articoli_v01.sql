-- Active: 1701850155359@@127.0.0.1@5432@prova_development
SELECT DISTINCT codice_articolo,
                descrizione,
                sum(quantita)      AS giacenza,
                sum(ROUND(importo_netto * 100))  AS valore
FROM view_righe
GROUP BY codice_articolo, descrizione
ORDER BY codice_articolo;