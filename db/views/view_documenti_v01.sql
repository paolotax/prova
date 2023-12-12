SELECT DISTINCT row_number() OVER (PARTITION BY true::boolean)::integer   AS id,
                imports.fornitore,
                imports.iva_fornitore,
                imports.cliente,
                imports.iva_cliente,
                imports.tipo_documento,
                imports.numero_documento,
                imports.data_documento,
                CASE
                    WHEN imports.tipo_documento::text = ANY
                         (ARRAY ['Nota di accredito'::character varying::text, 'TD04'::character varying::text])
                        THEN - sum(imports.quantita)
                    ELSE sum(imports.quantita)
                    END                                                   AS quantita_totale,
                CASE
                    WHEN imports.tipo_documento::text = ANY
                         (ARRAY ['Nota di accredito'::character varying::text, 'TD04'::character varying::text])
                        THEN - round(sum(imports.importo_netto * 100::double precision))
                    ELSE round(sum(imports.importo_netto * 100::double precision))
                    END                                                   AS importo_netto_totale,
                CASE
                    WHEN imports.tipo_documento::text = ANY
                         (ARRAY ['Nota di accredito'::character varying::text, 'TD04'::character varying::text])
                        THEN - round(imports.totale_documento * 100::double precision)
                    ELSE round(imports.totale_documento * 100::double precision)
                    END                                                   AS totale_documento,
                CASE
                    WHEN imports.iva_fornitore::text = '04155820378'::text THEN 'c.vendite'::text
                    ELSE 'c.acquisti'::text
                    END                                                   AS conto,
                round(imports.totale_documento * 100::double precision) -
                round(sum(imports.importo_netto) * 100::double precision) AS "check"
FROM imports
GROUP BY imports.fornitore, imports.iva_fornitore, imports.cliente, imports.iva_cliente, imports.tipo_documento,
         imports.numero_documento, imports.data_documento, imports.totale_documento
ORDER BY imports.fornitore, imports.data_documento DESC, imports.numero_documento, imports.tipo_documento;