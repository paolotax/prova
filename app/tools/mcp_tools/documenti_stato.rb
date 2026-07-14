module MCPTools
  class DocumentiStato < Base
    tool_name "documenti_stato"
    description "Gestisce lo stato di un documento: consegna, pagamento, chiusura, evidenza. Azioni: consegna, unconsegna, pagamento, unpagamento, close, reopen, gold, ungold."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    TIPI_PAGAMENTO = %w[contanti bonifico assegno ri.ba carta_di_credito bonus_docente bancomat satispay cedole].freeze

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID del documento" },
        azione: { type: "string", description: "Azione: consegna, unconsegna, pagamento, unpagamento, close, reopen, gold, ungold" },
        data: { type: "string", description: "Data (YYYY-MM-DD) per consegna o pagamento. Default: oggi" },
        tipo_pagamento: { type: "string", description: "Tipo pagamento: #{TIPI_PAGAMENTO.join(', ')}" },
        importo: { type: "string", description: "Solo per azione pagamento: importo dell'acconto in euro (es. \"200\" o \"200.50\"). Se assente salda tutto il residuo" },
        righe: { type: "object", description: "Solo per azione consegna: consegna parziale come mappa ISBN (o libro_id) => quantità, es. {\"9788809964686\": 10}. Se assente consegna tutto il residuo" }
      },
      required: %w[id azione]
    )

    def self.call(id:, azione:, data: nil, tipo_pagamento: nil, importo: nil, righe: nil, server_context:, **_params)
      with_current(server_context) do
        doc = Current.account.documenti.find(id)
        parsed_date = data.present? ? Date.parse(data) : nil

        case azione.downcase
        when "consegna"
          if righe.present?
            doc.consegna_parziale_per_libro!(righe, consegnato_il: parsed_date)
          else
            doc.mark_consegnato(consegnato_il: parsed_date)
          end
          result = { ok: true, azione: "consegna", consegnato: doc.consegnato?,
                     consegnato_il: doc.consegnato_il&.in_time_zone("Europe/Rome")&.to_date,
                     copie_consegnate: doc.copie_consegnate, copie_residue: doc.copie_residue_da_consegnare }
        when "unconsegna"
          doc.unmark_consegnato
          result = { ok: true, azione: "unconsegna", consegnato: false }
        when "pagamento"
          if importo.present?
            doc.registra_acconto!(importo_cents: (BigDecimal(importo.to_s) * 100).to_i,
                                  pagato_il: parsed_date, tipo_pagamento: tipo_pagamento)
          else
            doc.mark_pagato(pagato_il: parsed_date, tipo_pagamento: tipo_pagamento)
          end
          result = { ok: true, azione: "pagamento", pagato: doc.pagato?,
                     pagato_il: doc.pagato_il&.in_time_zone("Europe/Rome")&.to_date, tipo_pagamento: doc.tipo_pagamento,
                     pagato_cents: doc.pagato_cents, residuo_da_pagare_cents: doc.residuo_da_pagare_cents }
        when "unpagamento"
          doc.unmark_pagato
          result = { ok: true, azione: "unpagamento", pagato: false }
        when "close"
          doc.close
          result = { ok: true, azione: "close", closed: true }
        when "reopen"
          doc.reopen
          result = { ok: true, azione: "reopen", closed: false }
        when "gold"
          doc.gild
          result = { ok: true, azione: "gold", golden: true }
        when "ungold"
          doc.ungild
          result = { ok: true, azione: "ungold", golden: false }
        else
          return MCP::Tool::Response.new([{ type: "text", text: { error: "Azione non valida: #{azione}" }.to_json }], error: true)
        end

        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Documento non trovato" }.to_json }], error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
