SELECT DISTINCT
    row_number() OVER (PARTITION BY true::boolean)::integer   AS id,
    cliente,
    iva_cliente
FROM view_documenti WHERE iva_fornitore = (SELECT partita_iva FROM users LIMIT 1)
GROUP BY cliente, iva_cliente;