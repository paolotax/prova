module MCPTools
  class GiriList < Base
    tool_name "giri_list"
    description "Lista giri (tour di visite). Mostra titolo, date, numero tappe."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        limit: { type: "integer", description: "Max risultati (1-100, default 20)" }
      }
    )

    def self.call(limit: nil, server_context:, **_params)
      with_current(server_context) do
        giri = Current.user.giri.includes(:tappe).order(created_at: :desc).limit((limit || 20).to_i.clamp(1, 100))
        response = { results: giri.map { |g| format_giro(g) }, count: giri.size }
        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_giro(giro)
      {
        id: giro.id, titolo: giro.titolo, descrizione: giro.descrizione,
        iniziato_il: giro.iniziato_il, finito_il: giro.finito_il, color: giro.color,
        tappe_count: giro.tappe.size
      }
    end
  end
end
