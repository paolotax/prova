module MCPTools
  class LibriShow < Base
    tool_name "libri_show"
    description "Mostra dettagli di un libro: titolo, ISBN, editore, prezzo, disciplina."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "integer", description: "ID del libro" }
      },
      required: ["id"]
    )

    def self.call(id:, server_context:, **_params)
      with_current(server_context) do
        libro = Current.account.libri.includes(:editore, :categoria).find(id)

        result = {
          id: libro.id,
          titolo: libro.titolo,
          codice_isbn: libro.codice_isbn,
          prezzo_cents: libro.prezzo_in_cents,
          prezzo: libro.prezzo_in_cents ? "%.2f" % (libro.prezzo_in_cents / 100.0) : nil,
          prezzo_suggerito: libro.prezzo_suggerito_cents ? "%.2f" % (libro.prezzo_suggerito_cents / 100.0) : nil,
          editore: libro.editore&.editore,
          editore_id: libro.editore_id,
          disciplina: libro.disciplina,
          classe: libro.classe,
          collana: libro.collana,
          categoria: libro.categoria&.nome_categoria,
          note: libro.note,
          created_at: libro.created_at,
          updated_at: libro.updated_at
        }

        MCP::Tool::Response.new([{ type: "text", text: result.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Libro non trovato" }.to_json }], error: true)
      end
    end
  end
end
