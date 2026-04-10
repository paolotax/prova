module MCPTools
  class LibriUpdate < Base
    tool_name "libri_update"
    description "Aggiorna un libro: titolo, ISBN, prezzo, prezzo_suggerito, editore, disciplina, classe, note, collana."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "integer", description: "ID del libro" },
        titolo: { type: "string", description: "Titolo" },
        codice_isbn: { type: "string", description: "Codice ISBN" },
        prezzo: { type: "string", description: "Prezzo di vendita (es. '12.50')" },
        prezzo_suggerito: { type: "string", description: "Prezzo suggerito/consigliato (es. '14.90')" },
        editore: { type: "string", description: "Nome editore (cerca per nome)" },
        disciplina: { type: "string", description: "Disciplina" },
        classe: { type: "string", description: "Classe" },
        note: { type: "string", description: "Note" },
        collana: { type: "string", description: "Collana" }
      },
      required: ["id"]
    )

    def self.call(id:, titolo: nil, codice_isbn: nil, prezzo: nil, prezzo_suggerito: nil, editore: nil, disciplina: nil, classe: nil, note: nil, collana: nil, server_context:, **_params)
      with_current(server_context) do
        libro = Current.account.libri.find(id)

        attrs = { titolo: titolo, codice_isbn: codice_isbn, disciplina: disciplina, classe: classe, note: note, collana: collana }.compact
        if prezzo.present?
          attrs[:prezzo_in_cents] = (prezzo.to_s.gsub(",", ".").to_f * 100).round
        end
        if prezzo_suggerito.present?
          attrs[:prezzo_suggerito] = prezzo_suggerito.to_s.gsub(",", ".")
        end
        if editore.present?
          attrs[:editore_id] = Editore.find_or_create_by!(editore: editore, account: Current.account).id
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
