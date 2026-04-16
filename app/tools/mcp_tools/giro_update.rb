module MCPTools
  class GiroUpdate < Base
    tool_name "giro_update"
    description "Aggiorna un giro esistente."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID del giro" },
        titolo: { type: "string", description: "Titolo" },
        descrizione: { type: "string", description: "Descrizione" },
        iniziato_il: { type: "string", description: "Data inizio YYYY-MM-DD" },
        finito_il: { type: "string", description: "Data fine YYYY-MM-DD" }
      },
      required: ["id"]
    )

    def self.call(id:, titolo: nil, descrizione: nil, iniziato_il: nil, finito_il: nil, server_context:, **_params)
      with_current(server_context) do
        giro = Current.user.giri.find(id)
        attrs = { titolo: titolo, descrizione: descrizione }.compact
        attrs[:iniziato_il] = Date.parse(iniziato_il) if iniziato_il.present?
        attrs[:finito_il] = Date.parse(finito_il) if finito_il.present?
        giro.update!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: { id: giro.id, titolo: giro.titolo }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
