SELECT DISTINCT
    row_number() OVER (PARTITION BY true::boolean)::integer   AS id,
    fornitore,
    iva_fornitore
FROM view_documenti WHERE iva_cliente = (SELECT partita_iva FROM users LIMIT 1)
GROUP BY fornitore, iva_fornitore;