module MCPTools
  class AppuntiShow < Base
    tool_name "appunti_show"
    description "Mostra dettagli di un appunto con contenuto, attachments e stato entry."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID dell'appunto" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        appunto = Current.account.appunti.includes(:entry).find(id)
        result = {
          id: appunto.id, entry_id: appunto.entry&.id,
          nome: appunto.nome, numero: appunto.numero, status: appunto.status,
          content: appunto.content&.to_plain_text,
          telefono: appunto.telefono, email: appunto.email,
          appuntabile_type: appunto.appuntabile_type, appuntabile_display: appunto.appuntabile&.to_s,
          appuntabile_value: appunto.appuntabile ? "#{appunto.appuntabile_type}:#{appunto.appuntabile_id}" : nil,
          golden: appunto.golden?, closed: appunto.closed?, postponed: appunto.postponed?,
          attachments: appunto.attachments.map { |a| { filename: a.filename.to_s, content_type: a.content_type, byte_size: a.byte_size } },
          created_at: appunto.created_at, updated_at: appunto.updated_at
        }
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
