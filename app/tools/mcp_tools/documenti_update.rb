module MCPTools
  class DocumentiUpdate < Base
    tool_name "documenti_update"
    description "Aggiorna un documento (note, referente, righe). Le righe vengono sostituite con l'array fornito."

    annotations(read_only_hint: false, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        id: { type: "string", description: "UUID del documento" },
        note: { type: "string", description: "Note del documento" },
        referente: { type: "string", description: "Referente" },
        data_documento: { type: "string", description: "Data documento YYYY-MM-DD" },
        righe: { type: "string", description: "JSON array di righe. Ogni riga: {codice_isbn, quantita, prezzo_cents, sconto, libro_id, titolo}" }
      },
      required: ["id"]
    )

    def self.call(id:, note: nil, referente: nil, data_documento: nil, righe: nil, server_context:, **_params)
      with_current(server_context) do
        doc = Current.account.documenti.find(id)
        attrs = { note: note, referente: referente }.compact
        attrs[:data_documento] = Date.parse(data_documento) if data_documento.present?
        doc.update!(attrs)

        if righe.present?
          replace_righe(doc, JSON.parse(righe))
        end

        MCP::Tool::Response.new([{ type: "text", text: { id: doc.id, totale_cents: doc.totale_cents, totale_copie: doc.totale_copie }.to_json }])
      rescue ActiveRecord::RecordNotFound
        MCP::Tool::Response.new([{ type: "text", text: { error: "Record non trovato" }.to_json }], error: true)
      rescue JSON::ParserError => e
        MCP::Tool::Response.new([{ type: "text", text: { error: "JSON righe non valido: #{e.message}" }.to_json }], error: true)
      rescue => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end

    def self.replace_righe(doc, righe_array)
      doc.documento_righe.destroy_all
      righe_array.each do |rp|
        rp = rp.symbolize_keys
        libro = resolve_libro(rp)
        next unless libro

        riga = Riga.create!(
          libro: libro,
          quantita: (rp[:quantita] || 1).to_i,
          sconto: (rp[:sconto] || 0).to_f,
          prezzo_cents: rp[:prezzo_cents].present? ? rp[:prezzo_cents].to_i : libro.prezzo_in_cents,
          prezzo_copertina_cents: libro.prezzo_in_cents || 0
        )
        doc.documento_righe.create!(riga: riga)
      end
      doc.ricalcola_totali! if doc.respond_to?(:ricalcola_totali!)
    end

    def self.resolve_libro(rp)
      if rp[:libro_id].present?
        Current.account.libri.find_by(id: rp[:libro_id])
      elsif rp[:codice_isbn].present?
        Current.account.libri.find_by(codice_isbn: rp[:codice_isbn])
      elsif rp[:titolo].present?
        Current.account.libri.search_all_word(rp[:titolo]).first
      end
    end
  end
end
