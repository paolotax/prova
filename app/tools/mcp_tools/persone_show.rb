module MCPTools
  class PersoneShow < Base
    tool_name "persone_show"
    description "Mostra dettagli completi di una persona (nome, cognome, email, cellulare, ruolo, scuola, classi)"

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID della persona" }
      },
      required: [ "id" ]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        persona = Current.account.persone.includes(:scuola, :classi).find(id)

        result = {
          id: persona.id,
          cognome: persona.cognome,
          nome: persona.nome,
          email: persona.email,
          cellulare: persona.cellulare,
          telefono: persona.telefono,
          ruolo: persona.ruolo,
          note: persona.note,
          scuola: persona.scuola&.denominazione,
          scuola_id: persona.scuola_id,
          classi: persona.classi.map { |c| { id: c.id, display: c.to_combobox_display, anno_corso: c.anno_corso } },
          appuntabile_value: "Persona:#{persona.id}"
        }

        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
