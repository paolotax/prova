module MCPTools
  class ClientiShow < Base
    tool_name "clienti_show"
    description "Mostra dettagli completi di un cliente (denominazione, partita IVA, indirizzo, contatti)"

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID del cliente" }
      },
      required: [ "id" ]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        cliente = Current.account.clienti.find(id)

        result = {
          id: cliente.id,
          denominazione: cliente.denominazione,
          partita_iva: cliente.partita_iva,
          codice_fiscale: cliente.codice_fiscale,
          indirizzo: cliente.indirizzo,
          numero_civico: cliente.numero_civico,
          cap: cliente.cap,
          comune: cliente.comune,
          provincia: cliente.provincia,
          email: cliente.email,
          pec: cliente.pec,
          telefono: cliente.telefono,
          indirizzo_telematico: cliente.indirizzo_telematico,
          appuntabile_value: "Cliente:#{cliente.id}"
        }

        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      end
    end
  end
end
