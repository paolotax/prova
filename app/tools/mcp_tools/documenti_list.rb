module MCPTools
  class DocumentiList < Base
    tool_name "documenti_list"
    description "Lista documenti (ordini, fatture, DDT). Filtri per ricerca, causale, tipo destinatario, stato."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        search: { type: "string", description: "Cerca per cliente, referente" },
        causale: { type: "string", description: "Filtra per causale: Ordine Scuola, Ordine Cliente, TD01, TD04, DDT, Campionario, saggi" },
        clientable_type: { type: "string", description: "Filtra per tipo: Scuola, Cliente" },
        stato: { type: "string", description: "Filtra per stato: attivi, completati" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    def self.call(search: nil, causale: nil, clientable_type: nil, stato: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.documenti.includes(:causale, :clientable, entry: [:goldness, :closure])
        scope = scope.search_docs(search) if search.present?
        scope = scope.joins(:causale).where(causali: { causale: causale }) if causale.present?
        scope = scope.where(clientable_type: clientable_type) if clientable_type.present?
        scope = scope.send(stato) if stato.present? && %w[attivi completati].include?(stato)
        documenti = scope.order(created_at: :desc).limit((limit || 50).to_i.clamp(1, 200))

        response = { results: documenti.map { |d| format_documento(d) }, count: documenti.size }
        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_documento(doc)
      {
        id: doc.id, numero_documento: doc.numero_documento, data_documento: doc.data_documento,
        causale: doc.causale&.causale, totale_cents: doc.totale_cents, totale_copie: doc.totale_copie,
        clientable_type: doc.clientable_type, clientable_display: doc.clientable&.denominazione,
        clientable_value: doc.clientable ? "#{doc.clientable_type}:#{doc.clientable_id}" : nil,
        golden: doc.golden?, closed: doc.closed?,
        consegnato: doc.consegnato_il.present?, pagato: doc.pagato_il.present?
      }
    end
  end
end
