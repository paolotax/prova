module MCPTools
  class LibriList < Base
    tool_name "libri_list"
    description "Lista libri del catalogo con ricerca opzionale per titolo/ISBN."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per titolo o ISBN" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-50, default 20)" }
      }
    )

    def self.call(query: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        max = (limit || 20).to_i.clamp(1, 50)
        scope = Current.account.libri.includes(:editore)
        scope = scope.search_all_word(query) if query.present?
        libri = scope.limit(max)

        response = {
          results: libri.map { |l| format_libro(l) },
          count: libri.size
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_libro(libro)
      {
        id: libro.id,
        titolo: libro.titolo,
        codice_isbn: libro.codice_isbn,
        prezzo_cents: libro.prezzo_in_cents,
        prezzo: libro.prezzo_in_cents ? "%.2f" % (libro.prezzo_in_cents / 100.0) : nil,
        editore: libro.editore&.editore,
        disciplina: libro.disciplina,
        classe: libro.classe,
        collana: libro.collana
      }
    end
  end
end
