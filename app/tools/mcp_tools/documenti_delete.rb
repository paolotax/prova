module MCPTools
  class DocumentiDelete < Base
    tool_name "documenti_delete"
    description "Elimina un documento."

    annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID del documento da eliminare" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        Current.account.documenti.find(id).destroy!
        MCP::Tool::Response.new([{ type: "text", text: { deleted: true, id: id }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], is_error: true)
      end
    end
  end
end
