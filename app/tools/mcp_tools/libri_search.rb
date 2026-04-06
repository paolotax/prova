module MCPTools
  class LibriSearch < Base
    tool_name "libri_search"
    description "Cerca libri per titolo o codice ISBN. Restituisce id, titolo, ISBN, editore, prezzo e disponibilita."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Titolo o codice ISBN da cercare" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-50)" }
      },
      required: [ "query" ]
    )

    def self.call(query:, limit: nil, server_context:, **_params)
      with_current(server_context) do
        sanitized = query.to_s.strip

        if sanitized.length < 2
          return MCP::Tool::Response.new([{ type: "text", text: { results: [], count: 0 }.to_json }])
        end

        max = (limit || 10).to_i.clamp(1, 50)
        libri = Current.account.libri.search_all_word(sanitized).limit(max)

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
