module MCPTools
  class PersoneList < Base
    tool_name "persone"
    description "Elenca le persone (docenti, dirigenti, segretari) del tuo account Scagnozz. Filtri per ruolo, classe, materia, stato contatto."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per cognome o nome" },
        ruolo: { type: "string", description: "Filtra per ruolo: docente, dirigente, segretario, referente, altro" },
        anno_corso: { type: "string", description: "Anno corso 1-5, separati da virgola" },
        materia: { type: "string", description: "Filtra per materia insegnata" },
        stato_contatto: { type: "string", description: "Filtra per: con_email, con_telefono, con_scuola, senza_scuola" },
        scuola_id: { type: "string", description: "Filtra per scuola (UUID)" },
        sorted_by: { type: "string", description: "Ordinamento: cognome (default), scuola, recenti" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(query: nil, ruolo: nil, anno_corso: nil, materia: nil, stato_contatto: nil,
                  scuola_id: nil, sorted_by: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.persone.includes(:scuola, :classi)
        scope = scope.where(ruolo: ruolo) if ruolo.present?

        if anno_corso.present?
          anni = anno_corso.split(",").map(&:strip).map(&:to_i)
          scope = scope.joins(:classi).where(classi: { anno_corso: anni }).distinct
        end

        if materia.present?
          scope = scope.joins(:persona_classi).where("persona_classi.materia ILIKE ?", "%#{materia}%").distinct
        end

        case stato_contatto
        when "con_email"    then scope = scope.where.not(email: [nil, ""])
        when "con_telefono" then scope = scope.where.not(cellulare: [nil, ""])
        when "con_scuola"   then scope = scope.where.not(scuola_id: nil)
        when "senza_scuola" then scope = scope.where(scuola_id: nil)
        end

        scope = scope.where(scuola_id: scuola_id) if scuola_id.present?

        if query.present?
          query.split(/\s+/).each do |word|
            scope = scope.where("persone.cognome ILIKE :q OR persone.nome ILIKE :q", q: "%#{word}%")
          end
        end

        scope = scope.left_joins(:scuola) if sorted_by == "scuola"
        order = case sorted_by.to_s
                when "scuola"  then Arel.sql("scuole.denominazione ASC, persone.cognome, persone.nome")
                when "recenti" then { created_at: :desc }
                else { cognome: :asc, nome: :asc }
                end

        persone = scope.order(order).limit((limit || 50).to_i.clamp(1, 200))

        response = {
          results: persone.map { |p| format_persona(p) },
          count: persone.size
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_persona(persona)
      {
        id: persona.id,
        cognome: persona.cognome,
        nome: persona.nome,
        email: persona.email,
        cellulare: persona.cellulare,
        telefono: persona.telefono,
        scuola: persona.scuola&.denominazione,
        scuola_id: persona.scuola_id,
        classi: persona.classi.map { |c| { id: c.id, display: c.to_combobox_display, anno_corso: c.anno_corso } },
        appuntabile_value: "Persona:#{persona.id}"
      }
    end
  end
end
