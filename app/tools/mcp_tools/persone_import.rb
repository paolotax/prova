module MCPTools
  class PersoneImport < Base
    tool_name "persone_import"
    description "Importa una nuova persona con scuola e classi. La scuola viene cercata per nome (fuzzy match)."

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
        scuola: { type: "string", description: "Nome scuola per fuzzy match" },
        classi: { type: "array", items: { type: "string" }, description: "Lista classi (es. ['3A', '4B'])" },
        ruolo: { type: "string", description: "Ruolo: docente, dirigente, segretario, referente, altro" },
        materia: { type: "string", description: "Materia insegnata" }
      },
      required: [ "cognome" ]
    )

    def self.call(cognome:, nome: nil, email: nil, cellulare: nil, telefono: nil, scuola: nil, classi: nil, ruolo: nil, materia: nil, server_context:, **_params)
      with_current(server_context) do
        attrs = { cognome: cognome, nome: nome, email: email, cellulare: cellulare,
                  telefono: telefono, scuola: scuola, classi: classi, ruolo: ruolo || "docente",
                  materia: materia }.compact

        importer = ::Persone::Importer.new(**attrs).import

        if importer.ok?
          MCP::Tool::Response.new([{ type: "text", text: importer.result.to_json }])
        else
          MCP::Tool::Response.new([{ type: "text", text: importer.result.to_json }], error: true)
        end
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
