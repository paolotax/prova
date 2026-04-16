module MCPTools
  class LibriDelete < Base
    tool_name "libri_delete"
    description "Elimina un libro dal catalogo."

    annotations(read_only_hint: false, destructive_hint: true, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "integer", description: "ID del libro" }
      },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        libro = Current.account.libri.find(id)
        libro.destroy!

        MCP::Tool::Response.new([{ type: "text", text: { ok: true, deleted: true, id: id }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Libro non trovato" }.to_json }], error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
