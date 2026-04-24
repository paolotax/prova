module MCPTools
  class TappeShow < Base
    tool_name "tappe_show"
    description "Mostra dettagli di una tappa."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID della tappa" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        tappa = Current.user.tappe.includes(:tappable, :giri, :entry).find(id)
        result = TappeList.format_tappa(tappa).merge(created_at: tappa.created_at, updated_at: tappa.updated_at)
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
