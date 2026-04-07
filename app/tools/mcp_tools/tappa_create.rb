module MCPTools
  class TappaCreate < Base
    tool_name "tappa_create"
    description "Crea una nuova tappa (visita programmata). Associa a scuola, appunto o documento."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false)

    input_schema(
      type: "object",
      properties: {
        tappable_value: { type: "string", description: "Destinazione nel formato Tipo:UUID (es. Scuola:uuid)" },
        data_tappa: { type: "string", description: "Data della visita YYYY-MM-DD" },
        titolo: { type: "string", description: "Titolo/nota breve" },
        descrizione: { type: "string", description: "Note/descrizione" },
        giro_id: { type: "integer", description: "ID del giro a cui associare la tappa" }
      },
      required: ["tappable_value"]
    )

    def self.call(tappable_value:, data_tappa: nil, titolo: nil, descrizione: nil, giro_id: nil, server_context:, **_params)
      with_current(server_context) do
        tappa = Current.user.tappe.build(
          account: Current.account,
          tappable_value: tappable_value,
          data_tappa: data_tappa.present? ? Date.parse(data_tappa) : nil,
          titolo: titolo,
          descrizione: descrizione
        )
        tappa.save!

        if giro_id.present?
          giro = Current.user.giri.find(giro_id)
          tappa.tappa_giri.create!(giro: giro)
        end

        result = { success: true, id: tappa.id, titolo: tappa.titolo, data_tappa: tappa.data_tappa, tappable_display: tappa.tappable&.to_s, giro_id: giro_id }
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
