module MCPTools
  class AppuntiList < Base
    tool_name "appunti_list"
    description "Lista appunti pubblicati. Filtri per ricerca, stato (attivi/completati/rimandati/in_evidenza), tipo appuntabile."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        search: { type: "string", description: "Cerca per nome, scuola, cliente" },
        stato: { type: "string", description: "Filtra per stato: attivi, completati, rimandati, in_evidenza" },
        appuntabile_type: { type: "string", description: "Filtra per tipo: Scuola, Cliente, Persona" },
        anno: { type: "integer", description: "Filtra per anno (es. 2026)" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    def self.call(search: nil, stato: nil, appuntabile_type: nil, anno: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.appunti.published.includes(:appuntabile, entry: [:goldness, :closure, :not_now])
        scope = scope.search_appunti(search) if search.present?
        scope = scope.send(stato) if stato.present? && %w[attivi completati rimandati in_evidenza].include?(stato)
        scope = scope.where(appuntabile_type: appuntabile_type) if appuntabile_type.present?
        scope = scope.where("EXTRACT(YEAR FROM appunti.created_at) = ?", anno) if anno.present?
        appunti = scope.order(created_at: :desc).limit((limit || 50).to_i.clamp(1, 200))

        response = { results: appunti.map { |a| format_appunto(a) }, count: appunti.size }
        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_appunto(appunto)
      {
        id: appunto.id, nome: appunto.nome, numero: appunto.numero, status: appunto.status,
        totale_cents: appunto.totale_cents, totale_copie: appunto.totale_copie,
        appuntabile_type: appunto.appuntabile_type, appuntabile_display: appunto.appuntabile&.to_s,
        appuntabile_value: appunto.appuntabile ? "#{appunto.appuntabile_type}:#{appunto.appuntabile_id}" : nil,
        golden: appunto.golden?, closed: appunto.closed?, postponed: appunto.postponed?,
        created_at: appunto.created_at
      }
    end
  end
end
