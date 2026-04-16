module MCPTools
  class LibriImport < Base
    tool_name "libri_import"
    description "Importa un libro nel catalogo. Accetta input fuzzy (isbn con trattini, prezzo come stringa, editore per nome). Deduplica per ISBN nell'account."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: false
    )

    input_schema(
      type: "object",
      properties: {
        isbn: { type: "string", description: "ISBN (accetta trattini e spazi)" },
        codice_isbn: { type: "string", description: "Alias per isbn" },
        titolo: { type: "string", description: "Titolo del libro" },
        prezzo: { type: "string", description: "Prezzo come stringa (es. '12.50' o '12,50')" },
        prezzo_cents: { type: "integer", description: "Prezzo in centesimi" },
        editore: { type: "string", description: "Nome editore (trova o crea)" },
        editore_id: { type: "integer", description: "ID editore" },
        disciplina: { type: "string", description: "Disciplina / materia" },
        classe: { type: "string", description: "Classe (es. '1', '2')" },
        collana: { type: "string", description: "Collana" },
        categoria: { type: "string", description: "Categoria" },
        on_conflict: { type: "string", description: "Comportamento in caso di duplicato: update (default) o skip" }
      }
    )

    def self.call(isbn: nil, codice_isbn: nil, titolo: nil, prezzo: nil, prezzo_cents: nil,
                  editore: nil, editore_id: nil, disciplina: nil, classe: nil, collana: nil,
                  categoria: nil, on_conflict: nil, server_context:, **_params)
      with_current(server_context) do
        attrs = { isbn: isbn, codice_isbn: codice_isbn, titolo: titolo, prezzo: prezzo,
                  prezzo_in_cents: prezzo_cents, editore: editore, editore_id: editore_id,
                  disciplina: disciplina, classe: classe, collana: collana,
                  categoria: categoria }.compact

        importer = ::Libri::Importer.new(**attrs.merge(on_conflict: on_conflict || "update")).import

        if importer.ok?
          MCP::Tool::Response.new([{ type: "text", text: importer.batch_result.to_json }])
        else
          MCP::Tool::Response.new([{ type: "text", text: importer.batch_result.to_json }], error: true)
        end
      rescue ActiveRecord::RecordInvalid => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
