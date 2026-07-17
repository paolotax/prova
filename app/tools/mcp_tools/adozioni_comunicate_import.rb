module MCPTools
  class AdozioniComunicateImport < Base
    tool_name "adozioni_comunicate_import"
    description "Importa le adozioni comunicate da un editore (numero alunni per " \
                "classe/sezione) e le confronta con le adozioni esistenti, aggiornando " \
                "il numero alunni delle classi corrispondenti. Usare dopo aver estratto " \
                "le righe da un PDF o Excel dell'editore. Idempotente: rilanciare " \
                "aggiorna gli alunni senza duplicare. Risponde con riepilogo e discrepanze."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      required: %w[anno_scolastico righe],
      properties: {
        anno_scolastico: { type: "string", description: "Es. '202627' per il 2026/27" },
        editore: { type: "string", description: "Editore mittente, usato per le righe senza editore" },
        righe: {
          type: "array",
          description: "Una riga per classe/sezione. Se il documento raggruppa le sezioni (es. '5 A,B,C - 69 alunni totali') NON dividere: passare sezioni='A,B,C' e alunni=69.",
          items: {
            type: "object",
            required: %w[codicescuola ean classe alunni],
            properties: {
              codicescuola: { type: "string", description: "Codice meccanografico del plesso (es. REEE81001P)" },
              ean: { type: "string", description: "EAN/ISBN13, trattini e spazi ammessi" },
              titolo: { type: "string" },
              classe: { type: "string", description: "Anno di corso: 1..5" },
              sezioni: { type: "string", description: "'A' oppure 'A,B,C' se raggruppate (alunni = totale)" },
              alunni: { type: "integer", description: "Numero alunni (totale della riga)" },
              editore: { type: "string" },
              descrizione_scuola: { type: "string" },
              comune: { type: "string" },
              provincia: { type: "string" }
            }
          }
        }
      }
    )

    def self.call(anno_scolastico:, righe:, editore: nil, server_context:, **_params)
      with_current(server_context) do
        importer = ::Adozioni::Comunicate::Importer.new(
          account: account(server_context),
          anno_scolastico: anno_scolastico,
          fonte: "mcp",
          editore: editore
        )
        importer.import_rows(righe)

        MCP::Tool::Response.new([{ type: "text", text: importer.riepilogo.to_json }])
      rescue ActiveRecord::RecordInvalid, ArgumentError => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
