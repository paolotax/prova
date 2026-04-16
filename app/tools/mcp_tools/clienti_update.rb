module MCPTools
  class ClientiUpdate < Base
    tool_name "clienti_update"
    description "Aggiorna un cliente esistente"

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID del cliente" },
        denominazione: { type: "string", description: "Ragione sociale / denominazione" },
        partita_iva: { type: "string", description: "Partita IVA" },
        codice_fiscale: { type: "string", description: "Codice fiscale" },
        indirizzo: { type: "string", description: "Indirizzo" },
        numero_civico: { type: "string", description: "Numero civico" },
        cap: { type: "string", description: "CAP" },
        comune: { type: "string", description: "Comune" },
        provincia: { type: "string", description: "Provincia (sigla)" },
        email: { type: "string", description: "Indirizzo email" },
        pec: { type: "string", description: "PEC" },
        telefono: { type: "string", description: "Numero di telefono" },
        indirizzo_telematico: { type: "string", description: "Codice SDI" }
      },
      required: [ "id" ]
    )

    def self.call(id:, denominazione: nil, partita_iva: nil, codice_fiscale: nil, indirizzo: nil,
                  numero_civico: nil, cap: nil, comune: nil, provincia: nil,
                  email: nil, pec: nil, telefono: nil, indirizzo_telematico: nil,
                  server_context:, **_params)
      with_current(server_context) do
        attrs = { denominazione: denominazione, partita_iva: partita_iva, codice_fiscale: codice_fiscale,
                  indirizzo: indirizzo, numero_civico: numero_civico, cap: cap, comune: comune,
                  provincia: provincia, email: email, pec: pec, telefono: telefono,
                  indirizzo_telematico: indirizzo_telematico }.compact

        cliente = Current.account.clienti.find(id)
        cliente.update!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: cliente.reload.as_json.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
