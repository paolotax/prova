module MCPTools
  class AppuntiUpdate < Base
    tool_name "appunti_update"
    description "Aggiorna un appunto esistente (nome, contenuto, pubblica/bozza)."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID dell'appunto" },
        nome: { type: "string", description: "Titolo dell'appunto" },
        content: { type: "string", description: "Contenuto testuale" },
        publish: { type: "boolean", description: "Se true pubblica, se false torna in bozza" }
      },
      required: ["id"]
    )

    def self.call(id:, nome: nil, content: nil, publish: nil, server_context:, **_params)
      with_current(server_context) do
        appunto = Current.account.appunti.find(id)
        attrs = { nome: nome, content: content }.compact
        appunto.update!(attrs) if attrs.any?
        appunto.publish if publish == true
        appunto.unpublish if publish == false && appunto.respond_to?(:unpublish)

        MCP::Tool::Response.new([{ type: "text", text: { id: appunto.id, nome: appunto.nome, status: appunto.status }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
