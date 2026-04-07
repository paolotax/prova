module MCPTools
  class GiroCreate < Base
    tool_name "giro_create"
    description "Crea un nuovo giro (tour di visite)."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: false)

    input_schema(
      type: "object",
      properties: {
        titolo: { type: "string", description: "Titolo del giro" },
        descrizione: { type: "string", description: "Descrizione" },
        iniziato_il: { type: "string", description: "Data inizio YYYY-MM-DD" },
        finito_il: { type: "string", description: "Data fine YYYY-MM-DD" }
      },
      required: ["titolo"]
    )

    def self.call(titolo:, descrizione: nil, iniziato_il: nil, finito_il: nil, server_context:, **_params)
      with_current(server_context) do
        giro = Current.user.giri.build(
          account: Current.account,
          titolo: titolo,
          descrizione: descrizione,
          iniziato_il: iniziato_il.present? ? Date.parse(iniziato_il) : nil,
          finito_il: finito_il.present? ? Date.parse(finito_il) : nil
        )
        if giro.iniziato_il.present? && (giro.finito_il.blank? || giro.finito_il < giro.iniziato_il)
          giro.finito_il = giro.iniziato_il + 4.weeks
        end
        giro.save!

        result = { success: true, id: giro.id, titolo: giro.titolo, iniziato_il: giro.iniziato_il, finito_il: giro.finito_il }
        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
