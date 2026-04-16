module MCPTools
  class GiroDelete < Base
    tool_name "giro_delete"
    description "Elimina un giro. Fallisce se ha tappe associate."

    annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: false)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID del giro da eliminare" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        giro = Current.user.giri.find(id)
        unless giro.can_delete?
          return MCP::Tool::Response.new([{ type: "text", text: { error: "Non puoi eliminare un giro con tappe associate" }.to_json }], error: true)
        end
        giro.destroy!
        MCP::Tool::Response.new([{ type: "text", text: { deleted: true, id: id }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
