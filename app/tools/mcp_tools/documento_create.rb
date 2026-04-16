module MCPTools
  class DocumentoCreate < Base
    tool_name "documento_create"
    description "Crea un nuovo documento (ordine, fattura, DDT, campionario). Specificare causale, destinatario e opzionalmente le righe con i libri."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false
    )

    input_schema(
      type: "object",
      properties: {
        clientable_value: { type: "string", description: "Destinatario nel formato Tipo:UUID" },
        causale: { type: "string", description: "Tipo documento: Ordine Scuola, Ordine Cliente, TD01, TD04, DDT, Campionario, saggi" },
        righe: { type: "string", description: "JSON array di righe. Ogni riga: {codice_isbn, quantita, prezzo_cents, libro_id, sconto, titolo, descrizione}" },
        note: { type: "string", description: "Note del documento" },
        referente: { type: "string", description: "Nome del referente/insegnante" },
        data_documento: { type: "string", description: "Data documento in formato YYYY-MM-DD" },
        numero_documento: { type: "string", description: "Numero documento" },
        ddt_numero: { type: "string", description: "Numero DDT di riferimento" },
        spese_cents: { type: "integer", description: "Spese in centesimi" }
      },
      required: [ "clientable_value", "causale" ]
    )

    def self.call(clientable_value:, causale:, righe: nil, note: nil, referente: nil, data_documento: nil,
                  numero_documento: nil, ddt_numero: nil, spese_cents: nil,
                  server_context:, **_params)
      with_current(server_context) do
        righe_params = if righe.present?
          JSON.parse(righe).map { |r| r.symbolize_keys.slice(:libro_id, :quantita, :sconto, :prezzo_cents, :prezzo_unitario, :titolo, :descrizione, :codice_isbn) }
        else
          []
        end

        creator = Documenti::Creator.new(
          clientable_value: clientable_value,
          causale_nome: causale,
          note: note,
          referente: referente,
          data_documento: data_documento,
          numero_documento: numero_documento,
          ddt_numero: ddt_numero,
          spese_cents: spese_cents,
          righe_params: righe_params
        )
        creator.create

        if creator.ok?
          MCP::Tool::Response.new([{ type: "text", text: creator.result.to_json }])
        else
          MCP::Tool::Response.new([{ type: "text", text: creator.result.to_json }], error: true)
        end
      rescue JSON::ParserError => e
        MCP::Tool::Response.new([{ type: "text", text: { error: "JSON righe non valido: #{e.message}" }.to_json }], error: true)
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
