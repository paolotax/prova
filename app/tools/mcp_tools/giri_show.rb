module MCPTools
  class GiriShow < Base
    tool_name "giri_show"
    description "Mostra dettagli di un giro con la lista delle tappe."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: { id: { type: "string", description: "UUID del giro" } },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        giro = Current.user.giri.includes(tappe: :tappable).find(id)
        result = GiriList.format_giro(giro).merge(
          tappe: giro.tappe.order(:data_tappa, :position).map { |t|
            { id: t.id, titolo: t.titolo, data_tappa: t.data_tappa, tappable_type: t.tappable_type, tappable_id: t.tappable_id, tappable_display: t.tappable&.to_s, tappable_value: t.tappable ? "#{t.tappable_type}:#{t.tappable_id}" : nil, position: t.position, latitude: t.latitude, longitude: t.longitude }
          },
          created_at: giro.created_at, updated_at: giro.updated_at
        )
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], is_error: true)
      end
    end
  end
end
