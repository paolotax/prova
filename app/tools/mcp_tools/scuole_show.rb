module MCPTools
  class ScuoleShow < Base
    tool_name "scuole_show"
    description "Mostra dettagli completi di una scuola (denominazione, codice ministeriale, indirizzo, contatti)"

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID della scuola" }
      },
      required: [ "id" ]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        scuola = Current.scuole.find(id)

        result = {
          id: scuola.id,
          denominazione: scuola.denominazione,
          codice: scuola.codice,
          indirizzo: scuola.indirizzo,
          cap: scuola.cap,
          comune: scuola.comune,
          provincia: scuola.provincia,
          email: scuola.email,
          pec: scuola.pec,
          telefono: scuola.telefono,
          note: scuola.note,
          appuntabile_value: "Scuola:#{scuola.id}"
        }

        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], is_error: true)
      end
    end
  end
end
