module MCPTools
  class ScuoleList < Base
    tool_name "scuole_list"
    description "Lista scuole dell'utente (solo quelle nel tuo account Scagnozz, non il database nazionale). Cerca per denominazione, codice ministeriale, comune o provincia. Gli ID restituiti sono UUID interni, NON codici ministeriali."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per denominazione, codice ministeriale, comune o provincia" },
        provincia: { type: "string", description: "Filtra per provincia (sigla es. MO, BO oppure nome completo es. MODENA)" },
        area: { type: "string", description: "Filtra per area" },
        comune: { type: "string", description: "Filtra per comune" },
        tipo_scuola: { type: "string", description: "Filtra per tipo scuola" },
        appunti_filter: { type: "string", description: "Filtra per appunti: tutte (default), con_appunti" },
        adozioni_filter: { type: "string", description: "Filtra per adozioni: tutte (default), mie_adozioni, adozioni_concorrenza" },
        sorted_by: { type: "string", description: "Ordinamento: per_direzione (default), solo_scuole, denominazione" },
        offset: { type: "integer", description: "Salta i primi N risultati (per paginazione)" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(query: nil, provincia: nil, area: nil, comune: nil, tipo_scuola: nil,
                  appunti_filter: nil, adozioni_filter: nil, sorted_by: nil, offset: nil, limit: nil,
                  server_context:, **_params)
      with_current(server_context) do
        scope = Current.scuole
        scope = scope.search_all_word(query) if query.present?
        if provincia.present?
          scope = provincia.length <= 2 ? scope.where(sigla_provincia: provincia.upcase) : scope.where(provincia: provincia)
        end
        scope = scope.where(area: area) if area.present?
        scope = scope.where(comune: comune) if comune.present?
        scope = scope.where(tipo_scuola: tipo_scuola) if tipo_scuola.present?

        if appunti_filter == "con_appunti"
          scope = scope.joins(:appunti).merge(Current.user.appunti.attivi)
        end

        case adozioni_filter
        when "mie_adozioni"
          scope = scope.joins(classi: :adozioni).where(adozioni: { mia: true })
        when "adozioni_concorrenza"
          scope = scope.joins(classi: :adozioni).where(adozioni: { mia: false })
        end

        order = case sorted_by.to_s
                when "denominazione" then { denominazione: :asc }
                when "solo_scuole"   then Arel.sql("provincia, comune, denominazione")
                else Arel.sql("provincia, area NULLS FIRST, comune, denominazione")
                end

        scuole = scope.order(order).distinct.offset((offset || 0).to_i).limit((limit || 50).to_i.clamp(1, 200))

        response = {
          results: scuole.map { |s| format_scuola(s) },
          count: scuole.size
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_scuola(scuola)
      {
        id: scuola.id,
        denominazione: scuola.denominazione,
        codice: scuola.codice_ministeriale,
        comune: scuola.comune,
        provincia: scuola.provincia,
        email: scuola.email,
        telefono: scuola.telefono,
        appuntabile_value: "Scuola:#{scuola.id}"
      }
    end
  end
end
