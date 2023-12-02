SELECT id,
       fornitore,
       tipo_documento,
       numero_documento,
       data_documento,
       CASE
           WHEN tipo_documento::text = 'Nota di accredito'::text THEN - totale_documento
           ELSE totale_documento
           END AS totale_documento,
       riga,
       codice_articolo,
       descrizione,
       prezzo_unitario,
       CASE
           WHEN tipo_documento::text = 'Nota di accredito'::text THEN - quantita
           ELSE quantita
           END AS quantita,
       CASE
           WHEN tipo_documento::text = 'Nota di accredito'::text THEN - importo_netto
           ELSE importo_netto
           END AS importo_netto,
       sconto,
       iva
FROM imports;
