module MCPTools
  class FilterOptions < Base
    tool_name "filter_options"
    description "Restituisce le opzioni filtro disponibili per una risorsa (libri, clienti, documenti, scuole, persone). Utile per popolare menu di filtro nel CLI."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        resource: { type: "string", description: "Risorsa: libri, clienti, documenti, scuole, persone" }
      },
      required: ["resource"]
    )

    def self.call(resource:, server_context:, **_params)
      with_current(server_context) do
        unless FilterOptionsCatalog.known?(resource)
          return MCP::Tool::Response.new([{
            type: "text",
            text: { error: "Risorsa non valida. Usa: #{FilterOptionsCatalog.available.join(', ')}" }.to_json
          }])
        end

        options = FilterOptionsCatalog.for(resource, user: Current.user)
        MCP::Tool::Response.new([{ type: "text", text: { resource: resource, options: options }.to_json }])
      end
    end
  end
end
