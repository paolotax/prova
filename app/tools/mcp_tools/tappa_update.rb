module MCPTools
  class TappaUpdate < Base
    tool_name "tappa_update"
    description "Aggiorna una tappa (data, titolo, note, posizione)."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID della tappa" },
        data_tappa: { type: "string", description: "Nuova data YYYY-MM-DD (vuoto per rimuovere)" },
        titolo: { type: "string", description: "Titolo" },
        descrizione: { type: "string", description: "Note/descrizione" },
        position: { type: "integer", description: "Posizione nell'ordine del giorno" }
      },
      required: ["id"]
    )

    def self.call(id:, data_tappa: nil, titolo: nil, descrizione: nil, position: nil, server_context:, **_params)
      with_current(server_context) do
        tappa = Current.user.tappe.find(id)
        attrs = { titolo: titolo, descrizione: descrizione, position: position }.compact
        attrs[:data_tappa] = data_tappa.present? ? Date.parse(data_tappa) : nil if data_tappa != nil
        tappa.update!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: { id: tappa.id, titolo: tappa.titolo, data_tappa: tappa.data_tappa }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], is_error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
