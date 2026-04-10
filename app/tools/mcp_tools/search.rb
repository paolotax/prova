module MCPTools
  class Search < Base
    tool_name "search"
    description "Cerca tutto nel database dell'utente: scuole, libri, clienti, persone, appunti, classi, documenti. Restituisce risultati con appuntabile_value da usare per creare appunti o documenti. NON cerca nel database nazionale adozioni — per quello usa stats_adozioni."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    ALL_TYPES = %w[scuola libro cliente persona appunto classe documento].freeze

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Testo di ricerca (minimo 2 caratteri)" },
        type: { type: "string", description: "Filtra per tipo: #{ALL_TYPES.join(', ')} (default: tutti)" },
        limit: { type: "integer", description: "Numero massimo di risultati per tipo (1-20)" }
      },
      required: [ "query" ]
    )

    def self.call(query:, type: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        sanitized = sanitize_query(query)

        if sanitized.blank? || sanitized.length < 2
          return MCP::Tool::Response.new([{ type: "text", text: [].to_json }])
        end

        types = (type || ALL_TYPES.join(",")).split(",").map(&:strip).map(&:downcase)
        max = (limit || 6).to_i.clamp(1, 20)

        results = []
        results += search_scuole(sanitized, max) if types.include?("scuola")
        results += search_libri(sanitized, max) if types.include?("libro")
        results += search_clienti(sanitized, max) if types.include?("cliente")
        results += search_persone(sanitized, max) if types.include?("persona")
        results += search_appunti(sanitized, max) if types.include?("appunto")
        results += search_classi(sanitized, max) if types.include?("classe")
        results += search_documenti(sanitized, max) if types.include?("documento")

        MCP::Tool::Response.new([{ type: "text", text: results.to_json }])
      end
    end

    private

    def self.search_scuole(query, limit)
      Current.account.scuole
        .search_all_word(query)
        .limit(limit)
        .map { |r| format_result(r, "Scuola") }
    end

    def self.search_libri(query, limit)
      Current.account.libri
        .search_all_word(query)
        .limit(limit)
        .map { |r| format_libro(r) }
    end

    def self.search_clienti(query, limit)
      Current.account.clienti
        .search_all_word(query)
        .limit(limit)
        .map { |r| format_result(r, "Cliente") }
    end

    def self.search_persone(query, limit)
      scope = Current.account.persone.left_joins(:scuola).includes(:scuola)
      query.split(/\s+/).each do |word|
        scope = scope.where(
          "persone.cognome ILIKE :q OR persone.nome ILIKE :q OR scuole.denominazione ILIKE :q", q: "%#{word}%"
        )
      end
      scope.limit(limit).map { |r| format_result(r, "Persona") }
    end

    def self.search_appunti(query, limit)
      Current.account.appunti
        .search_appunti(query)
        .limit(limit)
        .map { |r| format_appunto(r) }
    end

    def self.search_classi(query, limit)
      Current.account.classi
        .search_all_word(query)
        .includes(:scuola)
        .limit(limit)
        .map { |r| format_result(r, "Classe") }
    end

    def self.search_documenti(query, limit)
      Current.account.documenti
        .search_docs(query)
        .limit(limit)
        .map { |r| format_documento(r) }
    end

    def self.format_result(record, type)
      {
        id: record.id,
        type: type,
        appuntabile_value: "#{type}:#{record.id}",
        display: record.to_combobox_display
      }
    end

    def self.format_libro(libro)
      {
        id: libro.id,
        type: "Libro",
        display: libro.titolo,
        codice_isbn: libro.codice_isbn,
        prezzo: libro.prezzo_in_cents ? "%.2f" % (libro.prezzo_in_cents / 100.0) : nil,
        editore: libro.editore&.editore
      }
    end

    def self.format_appunto(appunto)
      {
        id: appunto.id,
        type: "Appunto",
        appuntabile_value: "#{appunto.appuntabile_type}:#{appunto.appuntabile_id}",
        display: appunto.nome
      }
    end

    def self.format_documento(documento)
      {
        id: documento.id,
        type: "Documento",
        display: [documento.causale&.causale, documento.referente].compact.join(" - ")
      }
    end

    def self.sanitize_query(query)
      return nil if query.blank?

      query.to_s
        .sub(/\A\[[^\]]+\]\s*/, "")
        .gsub(/\s*-\s*$/, "")
        .gsub(/\s+-\s+/, " ")
        .strip
    end
  end
end
