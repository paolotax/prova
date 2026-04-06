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
        con_email: { type: "boolean", description: "Solo persone con email" },
        scuola_id: { type: "string", description: "Filtra per scuola (UUID)" },
        sort: { type: "string", description: "Ordinamento: cognome (default) o recenti" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-200, default 50)" }
      }
    )

    def self.call(query: nil, ruolo: nil, anno_corso: nil, con_email: nil, scuola_id: nil, sort: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.persone.includes(:scuola, :classi)

        if ruolo.present?
          scope = scope.where(ruolo: ruolo)
        end

        if anno_corso.present?
          anni = anno_corso.split(",").map(&:strip).map(&:to_i)
          scope = scope.joins(:classi).where(classi: { anno_corso: anni }).distinct
        end

        if con_email
          scope = scope.where.not(email: [ nil, "" ])
        end

        if scuola_id.present?
          scope = scope.where(scuola_id: scuola_id)
        end

        if query.present?
          query.split(/\s+/).each do |word|
            scope = scope.where("persone.cognome ILIKE :q OR persone.nome ILIKE :q", q: "%#{word}%")
          end
        end

        order = sort == "recenti" ? { created_at: :desc } : { cognome: :asc, nome: :asc }
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
