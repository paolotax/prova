SELECT id,
       fornitore,
       iva_fornitore,
       cliente,
       iva_cliente,
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
       iva,
        CASE
          WHEN iva_fornitore = (SELECT partita_iva from users LIMIT 1) THEN 'c.vendita'
          ELSE 'c.acquisti'
          END AS conto
    FROM imports;