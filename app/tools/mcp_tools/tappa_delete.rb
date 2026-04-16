module MCPTools
  class TappaDelete < Base
    tool_name "tappa_delete"
    description "Elimina una tappa."

    annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID della tappa da eliminare" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        Current.user.tappe.find(id).destroy!
        MCP::Tool::Response.new([{ type: "text", text: { deleted: true, id: id }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
