module MCPTools
  class TappeList < Base
    tool_name "tappe_list"
    description "Lista tappe (visite programmate). Filtri per data, stato, ricerca."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        filter: { type: "string", description: "Filtra per: oggi, domani, settimana, mese, programmate, completate, da_programmare" },
        search: { type: "string", description: "Cerca per scuola, comune, titolo" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    def self.call(filter: nil, search: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.user.tappe.includes(:tappable, :giri)
        scope = scope.search(search) if search.present?
        case filter
        when "oggi" then scope = scope.di_oggi
        when "domani" then scope = scope.di_domani
        when "settimana" then scope = scope.della_settimana
        when "mese" then scope = scope.del_mese
        when "programmate" then scope = scope.programmate
        when "completate" then scope = scope.completate
        when "da_programmare" then scope = scope.da_programmare
        end
        tappe = scope.order(data_tappa: :asc, position: :asc).limit((limit || 50).to_i.clamp(1, 200))

        response = { results: tappe.map { |t| format_tappa(t) }, count: tappe.size }
        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_tappa(tappa)
      {
        id: tappa.id, titolo: tappa.titolo, data_tappa: tappa.data_tappa, descrizione: tappa.descrizione, position: tappa.position,
        tappable_type: tappa.tappable_type, tappable_display: tappa.tappable&.to_s,
        tappable_value: tappa.tappable ? "#{tappa.tappable_type}:#{tappa.tappable_id}" : nil,
        comune: tappa.tappable.respond_to?(:comune) ? tappa.tappable.comune : nil,
        giri: tappa.giri.map { |g| { id: g.id, titolo: g.titolo } }
      }
    end
  end
end
