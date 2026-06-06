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
        tipo_pagamento: { type: "string", description: "Tipo pagamento: #{TIPI_PAGAMENTO.join(', ')}" }
      },
      required: %w[id azione]
    )

    def self.call(id:, azione:, data: nil, tipo_pagamento: nil, server_context:, **_params)
      with_current(server_context) do
        doc = Current.account.documenti.find(id)
        parsed_date = data.present? ? Date.parse(data) : nil

        case azione.downcase
        when "consegna"
          doc.mark_consegnato(consegnato_il: parsed_date)
          result = { ok: true, azione: "consegna", consegnato: true, consegnato_il: doc.consegnato_il&.in_time_zone("Europe/Rome")&.to_date }
        when "unconsegna"
          doc.unmark_consegnato
          result = { ok: true, azione: "unconsegna", consegnato: false }
        when "pagamento"
          doc.mark_pagato(pagato_il: parsed_date, tipo_pagamento: tipo_pagamento)
          result = { ok: true, azione: "pagamento", pagato: true, pagato_il: doc.pagato_il&.in_time_zone("Europe/Rome")&.to_date, tipo_pagamento: doc.tipo_pagamento }
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
