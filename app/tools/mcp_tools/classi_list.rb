module MCPTools
  class ClassiList < Base
    tool_name "classi_list"
    description "Lista classi delle scuole del tuo account, filtrabili per combinazione (es. tempo pieno, tempo normale), provincia, comune, tipo_scuola. Utile per trovare scuole con tempo pieno."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        combinazione: { type: "string", description: "Filtra per combinazione (es. TEMPO PIENO, TEMPO NORMALE). Usa ILIKE, basta una parte del nome." },
        provincia: { type: "string", description: "Filtra per provincia della scuola (sigla es. RE, MO)" },
        comune: { type: "string", description: "Filtra per comune della scuola" },
        tipo_scuola: { type: "string", description: "Filtra per tipo scuola (es. EE, MM)" },
        anno_corso: { type: "string", description: "Filtra per anno corso (es. 1, 2, 3)" },
        group_by_scuola: { type: "boolean", description: "Se true, raggruppa le classi per scuola (default false)" },
        offset: { type: "integer", description: "Salta i primi N risultati (per paginazione)" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(combinazione: nil, provincia: nil, comune: nil, tipo_scuola: nil,
                  anno_corso: nil, group_by_scuola: false, offset: nil, limit: nil,
                  server_context:, **_params)
      with_current(server_context) do
        scope = Classe.where(account: Current.account)
          .joins(:scuola)
          .where(scuola: { id: Current.scuole.select(:id) })

        scope = scope.where("classi.combinazione ILIKE ?", "%#{combinazione}%") if combinazione.present?
        if provincia.present?
          scope = provincia.length <= 2 ? scope.where(scuole: { sigla_provincia: provincia.upcase }) : scope.where(scuole: { provincia: provincia })
        end
        scope = scope.where(scuole: { comune: comune }) if comune.present?
        scope = scope.where(tipo_scuola: tipo_scuola) if tipo_scuola.present?
        scope = scope.where(anno_corso: anno_corso) if anno_corso.present?

        scope = scope.includes(:scuola).order("scuole.provincia, scuole.comune, scuole.denominazione, classi.anno_corso, classi.sezione")

        total = scope.count
        classi = scope.offset((offset || 0).to_i).limit((limit || 50).to_i.clamp(1, 200))

        if group_by_scuola
          grouped = classi.group_by(&:scuola).map do |scuola, scuola_classi|
            {
              scuola_id: scuola.id,
              denominazione: scuola.denominazione,
              comune: scuola.comune,
              provincia: scuola.provincia,
              classi: scuola_classi.map { |c| format_classe(c) }
            }
          end
          response = { results: grouped, total: total }
        else
          response = { results: classi.map { |c| format_classe_with_scuola(c) }, total: total }
        end

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_classe(classe)
      {
        id: classe.id,
        anno_corso: classe.anno_corso,
        sezione: classe.sezione,
        combinazione: classe.combinazione,
        tipo_scuola: classe.tipo_scuola,
        numero_alunni: classe.numero_alunni
      }
    end

    def self.format_classe_with_scuola(classe)
      format_classe(classe).merge(
        scuola_id: classe.scuola_id,
        scuola_denominazione: classe.scuola.denominazione,
        scuola_comune: classe.scuola.comune,
        scuola_provincia: classe.scuola.provincia
      )
    end
  end
end
