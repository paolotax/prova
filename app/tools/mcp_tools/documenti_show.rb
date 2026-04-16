module MCPTools
  class DocumentiShow < Base
    tool_name "documenti_show"
    description "Mostra dettagli di un documento con righe, importi e catena documenti."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID del documento" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        doc = Current.account.documenti.includes(:causale, :clientable, documento_righe: { riga: :libro }).find(id)
        result = {
          id: doc.id, numero_documento: doc.numero_documento, data_documento: doc.data_documento,
          causale: doc.causale&.causale, note: doc.note, referente: doc.referente,
          totale_cents: doc.totale_cents, spese_cents: doc.spese_cents, totale_copie: doc.totale_copie,
          clientable_type: doc.clientable_type, clientable_display: doc.clientable&.denominazione,
          clientable_value: doc.clientable ? "#{doc.clientable_type}:#{doc.clientable_id}" : nil,
          golden: doc.golden?, closed: doc.closed?,
          consegnato: doc.consegnato_il.present?, consegnato_il: doc.consegnato_il,
          pagato: doc.pagato_il.present?, pagato_il: doc.pagato_il, tipo_pagamento: doc.tipo_pagamento,
          righe: doc.documento_righe.map { |dr|
            r = dr.riga
            { libro_id: r.libro_id, codice_isbn: r.libro&.codice_isbn, titolo: r.libro&.titolo,
              quantita: r.quantita, prezzo_cents: r.prezzo_cents, sconto: r.sconto, importo_cents: r.importo_cents }
          },
          documento_padre_id: doc.documento_padre_id,
          documenti_derivati: doc.documenti_derivati.map { |d| { id: d.id, causale: d.causale&.causale, numero_documento: d.numero_documento } }
        }
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
