module MCPTools
  class ClientiImport < Base
    tool_name "clienti_import"
    description "Importa un cliente (libreria, cartoleria, scuola). Accetta input fuzzy (nome→denominazione, piva→partita_iva, citta→comune, sdi→indirizzo_telematico). Deduplica per partita IVA o codice fiscale."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false
    )

    input_schema(
      type: "object",
      properties: {
        nome: { type: "string", description: "Alias per denominazione" },
        denominazione: { type: "string", description: "Ragione sociale / denominazione" },
        piva: { type: "string", description: "Alias per partita_iva" },
        partita_iva: { type: "string", description: "Partita IVA" },
        cf: { type: "string", description: "Alias per codice_fiscale" },
        codice_fiscale: { type: "string", description: "Codice fiscale" },
        indirizzo: { type: "string", description: "Indirizzo" },
        cap: { type: "string", description: "CAP" },
        citta: { type: "string", description: "Alias per comune" },
        comune: { type: "string", description: "Comune" },
        provincia: { type: "string", description: "Provincia (sigla)" },
        email: { type: "string", description: "Indirizzo email" },
        telefono: { type: "string", description: "Numero di telefono" },
        pec: { type: "string", description: "PEC" },
        sdi: { type: "string", description: "Alias per indirizzo_telematico" },
        indirizzo_telematico: { type: "string", description: "Codice SDI" },
        on_conflict: { type: "string", description: "Comportamento in caso di duplicato: update (default) o skip" }
      }
    )

    def self.call(nome: nil, denominazione: nil, piva: nil, partita_iva: nil, cf: nil, codice_fiscale: nil,
                  indirizzo: nil, cap: nil, citta: nil, comune: nil, provincia: nil,
                  email: nil, telefono: nil, pec: nil, sdi: nil, indirizzo_telematico: nil,
                  on_conflict: nil, server_context:, **_params)
      with_current(server_context) do
        attrs = { nome: nome, denominazione: denominazione, piva: piva, partita_iva: partita_iva,
                  cf: cf, codice_fiscale: codice_fiscale, indirizzo: indirizzo, cap: cap,
                  citta: citta, comune: comune, provincia: provincia, email: email,
                  telefono: telefono, pec: pec, sdi: sdi, indirizzo_telematico: indirizzo_telematico,
                  on_conflict: on_conflict || "update" }.compact

        importer = ::Clienti::Importer.new(**attrs).import

        if importer.ok?
          MCP::Tool::Response.new([{ type: "text", text: importer.batch_result.to_json }])
        else
          MCP::Tool::Response.new([{ type: "text", text: importer.batch_result.to_json }], is_error: true)
        end
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
