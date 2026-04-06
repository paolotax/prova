module MCPTools
  class ScuoleList < Base
    tool_name "scuole_list"
    description "Lista scuole con ricerca per denominazione, codice ministeriale, comune o provincia."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per denominazione, codice ministeriale, comune o provincia" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(query: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.scuole

        if query.present?
          scope = scope.search_all_word(query)
        end

        scuole = scope.limit((limit || 50).to_i.clamp(1, 200))

        response = {
          results: scuole.map { |s| format_scuola(s) },
          count: scuole.size
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_scuola(scuola)
      {
        id: scuola.id,
        denominazione: scuola.denominazione,
        codice: scuola.codice,
        comune: scuola.comune,
        provincia: scuola.provincia,
        email: scuola.email,
        telefono: scuola.telefono,
        appuntabile_value: "Scuola:#{scuola.id}"
      }
    end
  end
end
