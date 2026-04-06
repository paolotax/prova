module MCPTools
  class PersoneCreate < Base
    tool_name "persone_create"
    description "Crea una nuova persona (docente, dirigente, segretario) con nome, contatti e scuola"

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false
    )

    input_schema(
      type: "object",
      properties: {
        cognome: { type: "string", description: "Cognome della persona" },
        nome: { type: "string", description: "Nome della persona" },
        email: { type: "string", description: "Indirizzo email" },
        cellulare: { type: "string", description: "Numero di cellulare" },
        telefono: { type: "string", description: "Numero di telefono" },
        ruolo: { type: "string", description: "Ruolo: docente, dirigente, segretario, referente, altro" },
        note: { type: "string", description: "Note aggiuntive" },
        scuola_id: { type: "string", description: "UUID della scuola" }
      }
    )

    def self.call(cognome: nil, nome: nil, email: nil, cellulare: nil, telefono: nil, ruolo: nil, note: nil, scuola_id: nil, server_context:, **_params)
      with_current(server_context) do
        attrs = { cognome: cognome, nome: nome, email: email, cellulare: cellulare,
                  telefono: telefono, ruolo: ruolo, note: note, scuola_id: scuola_id }.compact

        persona = Current.account.persone.create!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: persona.as_json.to_json }])
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
