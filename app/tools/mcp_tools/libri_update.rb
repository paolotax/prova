module MCPTools
  class LibriUpdate < Base
    tool_name "libri_update"
    description "Aggiorna un libro: titolo, prezzo, disciplina, classe, note, collana."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "integer", description: "ID del libro" },
        titolo: { type: "string", description: "Titolo" },
        prezzo: { type: "string", description: "Prezzo (es. '12.50')" },
        disciplina: { type: "string", description: "Disciplina" },
        classe: { type: "string", description: "Classe" },
        note: { type: "string", description: "Note" },
        collana: { type: "string", description: "Collana" }
      },
      required: ["id"]
    )

    def self.call(id:, titolo: nil, prezzo: nil, disciplina: nil, classe: nil, note: nil, collana: nil, server_context:, **_params)
      with_current(server_context) do
        libro = Current.account.libri.find(id)

        attrs = { titolo: titolo, disciplina: disciplina, classe: classe, note: note, collana: collana }.compact
        if prezzo.present?
          attrs[:prezzo_in_cents] = (prezzo.to_s.gsub(",", ".").to_f * 100).round
        end

        libro.update!(attrs)

        MCP::Tool::Response.new([{ type: "text", text: { ok: true, id: libro.id, titolo: libro.titolo }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Libro non trovato" }.to_json }], is_error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], is_error: true)
      end
    end
  end
end
