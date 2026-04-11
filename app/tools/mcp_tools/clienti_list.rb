module MCPTools
  class ClientiList < Base
    tool_name "clienti_list"
    description "Lista clienti del tuo account Scagnozz. Ricerca opzionale per denominazione, partita IVA, comune."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per denominazione, partita IVA, comune" },
        comune: { type: "string", description: "Filtra per comune" },
        tipo_cliente: { type: "string", description: "Filtra per tipo cliente" },
        sorted_by: { type: "string", description: "Ordinamento: denominazione (default), comune, created_at" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(query: nil, comune: nil, tipo_cliente: nil, sorted_by: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.clienti
        scope = scope.search_all_word(query) if query.present?
        scope = scope.where(comune: comune) if comune.present?
        scope = scope.where(tipo_cliente: tipo_cliente) if tipo_cliente.present?

        order = case sorted_by.to_s
                when "comune"     then { comune: :asc, denominazione: :asc }
                when "created_at" then { created_at: :desc }
                else { denominazione: :asc }
                end

        clienti = scope.order(order).limit((limit || 50).to_i.clamp(1, 200))

        response = {
          results: clienti.map { |c| format_cliente(c) },
          count: clienti.size
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_cliente(cliente)
      {
        id: cliente.id,
        denominazione: cliente.denominazione,
        partita_iva: cliente.partita_iva,
        codice_fiscale: cliente.codice_fiscale,
        comune: cliente.comune,
        provincia: cliente.provincia,
        email: cliente.email,
        telefono: cliente.telefono,
        appuntabile_value: "Cliente:#{cliente.id}"
      }
    end
  end
end
