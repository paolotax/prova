module MCPTools
  class ScuoleUpdate < Base
    tool_name "scuole_update"
    description "Aggiorna dati di una scuola (email, PEC, telefono, note)"

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID della scuola" },
        email: { type: "string", description: "Indirizzo email" },
        pec: { type: "string", description: "PEC" },
        telefono: { type: "string", description: "Numero di telefono" },
        note: { type: "string", description: "Note" }
      },
      required: [ "id" ]
    )

    def self.call(id:, email: nil, pec: nil, telefono: nil, note: nil, server_context:, **_params)
      with_current(server_context) do
        attrs = { email: email, pec: pec, telefono: telefono, note: note }.compact

        scuola = Current.scuole.find(id)
        scuola.update!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: scuola.reload.as_json.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], is_error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
