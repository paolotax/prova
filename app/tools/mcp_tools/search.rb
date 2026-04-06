module MCPTools
  class Search < Base
    tool_name "search"
    description "Cerca scuole, clienti, classi e persone nel database dell'utente (dati del tuo account Scagnozz). Restituisce risultati con appuntabile_value da usare per creare appunti o documenti. NON cerca nel database nazionale adozioni — per quello usa stats_adozioni."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Testo di ricerca (minimo 2 caratteri)" },
        type: { type: "string", description: "Filtra per tipo: scuola, cliente, classe, persona" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-20)" }
      },
      required: [ "query" ]
    )

    def self.call(query:, type: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        sanitized = sanitize_query(query)

        if sanitized.blank? || sanitized.length < 2
          return MCP::Tool::Response.new([{ type: "text", text: [].to_json }])
        end

        types = (type || "scuola,cliente,classe,persona").split(",").map(&:strip).map(&:downcase)
        max = (limit || 6).to_i.clamp(1, 20)

        results = []
        results += search_scuole(sanitized, max) if types.include?("scuola")
        results += search_clienti(sanitized, max) if types.include?("cliente")
        results += search_classi(sanitized, max) if types.include?("classe")
        results += search_persone(sanitized, max) if types.include?("persona")

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

    def self.search_clienti(query, limit)
      Current.account.clienti
        .search_all_word(query)
        .limit(limit)
        .map { |r| format_result(r, "Cliente") }
    end

    def self.search_classi(query, limit)
      Current.account.classi
        .search_all_word(query)
        .includes(:scuola)
        .limit(limit)
        .map { |r| format_result(r, "Classe") }
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

    def self.format_result(record, type)
      {
        id: record.id,
        type: type,
        appuntabile_value: "#{type}:#{record.id}",
        display: record.to_combobox_display
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
