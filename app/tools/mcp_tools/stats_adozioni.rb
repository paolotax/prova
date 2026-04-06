module MCPTools
  class StatsAdozioni < Base
    tool_name "stats_adozioni"
    description "Statistiche adozioni elementari dal database nazionale (dati pubblici MIUR, non legati al tuo account). Filtra per provincia, comune, classe, editore, disciplina, titolo, isbn. Aggrega con group_by: editore, disciplina, classe, provincia, comune, titolo, scuola. La provincia accetta sia il nome completo (PRATO) che la sigla (PO)."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        group_by: { type: "string", description: "Dimensioni di aggregamento (virgola-separati): editore, disciplina, classe, provincia, comune, titolo, scuola" },
        provincia: { type: "string", description: "Provincia — nome completo (es. PRATO, MODENA) o sigla (es. PO, MO). Viene convertita automaticamente." },
        comune: { type: "string", description: "Nome del comune (es. MILANO, FIRENZE). Ricerca parziale." },
        regione: { type: "string", description: "Nome regione (es. PIEMONTE, TOSCANA)" },
        classe: { type: "string", description: "Anno corso: 1, 2, 3, 4, 5" },
        editore: { type: "string", description: "Nome editore (es. PEARSON)" },
        disciplina: { type: "string", description: "Materia (es. MATEMATICA, ITALIANO, LINGUA INGLESE)" },
        titolo: { type: "string", description: "Ricerca parziale nel titolo" },
        isbn: { type: "string", description: "Codice ISBN" },
        scuola: { type: "string", description: "Ricerca parziale nel nome della scuola" },
        codice_scuola: { type: "string", description: "Codice ministeriale esatto (es. MOEE804012)" },
        combinazione: { type: "string", description: "Combinazione" },
        coefficiente: { type: "integer", description: "Alunni per classe per stima copie (default 18)" },
        order_by: { type: "string", description: "Ordinamento: classi_count (default), adozioni_count, percentuale, importo" },
        limit: { type: "integer", description: "Max risultati (default 50)" }
      },
      required: ["group_by"]
    )

    def self.call(group_by:, provincia: nil, comune: nil, regione: nil, classe: nil, editore: nil, disciplina: nil, titolo: nil, isbn: nil, scuola: nil, codice_scuola: nil, combinazione: nil, coefficiente: 18, order_by: "classi_count", limit: 50, server_context:, **_params)
      with_current(server_context) do
        filters = {
          provincia: provincia, comune: comune, regione: regione, classe: classe,
          editore: editore, disciplina: disciplina, titolo: titolo, isbn: isbn,
          combinazione: combinazione, scuola: scuola, codice_scuola: codice_scuola
        }.compact_blank

        query = ::Stats::AdozioniQuery.new(
          filters: filters,
          group_by: group_by.split(",").map(&:strip),
          coefficiente: coefficiente.to_i,
          order_by: order_by.to_sym,
          limit: limit.to_i
        )

        result = query.call

        response = {
          ok: true,
          query: filters,
          count: result[:results]&.size || 0,
          data: result,
          actions: []
        }

        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end
  end
end
