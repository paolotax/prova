module MCPTools
  class StatsNewAdozioni < Base
    tool_name "stats_new_adozioni"
    description "Statistiche adozioni dal database nazionale MIUR aggiornato (new_adozioni/new_scuole — dati pubblici, non legati al tuo account). Stessa interfaccia di stats_adozioni ma interroga le tabelle new_adozioni e new_scuole, aggiornate ad ogni sync MIUR. Di default interroga tutti i gradi (elementari + medie + superiori); restringi con il filtro `grado` (E=elementari, M=medie, N=superiori, virgola-separati). Il filtro `filiera` (liceo|tecnico|professionale|altro, virgola-separati) distingue le scuole superiori per tipologia. Filtra per area (NORD OVEST|NORD EST|CENTRO|SUD|ISOLE), regione, provincia, comune, classe, editore, disciplina, titolo, isbn. Aggrega con group_by: editore, disciplina, classe, area, regione, provincia, comune, titolo, isbn (source of truth), scuola, grado, tipo_scuola, filiera. La provincia accetta sia il nome completo (PRATO) che la sigla (PO). Con `include_sezioni: true` ogni riga riporta anche l'array delle sezioni coinvolte (es. \"5A [C]\") — utile soprattutto per l'analisi di una singola scuola."

    annotations(
      read_only_hint: true,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      properties: {
        group_by: { type: "string", description: "Dimensioni di aggregamento (virgola-separati): editore, disciplina, classe, area, regione, provincia, comune, titolo, isbn (source of truth), scuola, grado, tipo_scuola, filiera" },
        grado: { type: "string", description: "Grado scolastico: E (elementari), M (medie), N (superiori). Accetta anche gli alias: elementari, medie, superiori. Virgola-separati per più gradi (es. 'M,N'). Se omesso, include tutti e tre." },
        filiera: { type: "string", description: "Filiera superiori: liceo, tecnico, professionale, altro. Virgola-separati (es. 'tecnico,professionale'). Match sul testo di tipi_scuole.tipo (LICEO%, IST PROF%, ISTITUTO TECNICO%/IST TEC%)." },
        area: { type: "string", description: "Macroarea geografica MIUR (esatta): NORD OVEST, NORD EST, CENTRO, SUD, ISOLE." },
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
        coefficiente: { type: "integer", description: "Alunni per classe per stima copie (default 17)" },
        order_by: { type: "string", description: "Ordinamento: classi_count (default), adozioni_count, percentuale, importo" },
        offset: { type: "integer", description: "Salta i primi N gruppi (per paginazione). Default 0." },
        limit: { type: "integer", description: "Max risultati (1-200, default 50). La response include pagination.total_groups per sapere quante pagine esistono." },
        solo_144: { type: "boolean", description: "Se true (solo per elementari), filtra le discipline che determinano il mercato (libro della prima, sussidiario linguaggi, sussidiario discipline di classe 1 e 4) e calcola sezioni_144 pesate (peso 1 per unico, 0.5 per fascicolo). Ignorato se il filtro grado include M o N." },
        include_sezioni: { type: "boolean", description: "Se true, per ogni riga restituisce l'array `sezioni` (es. [\"5A\", \"5B [C]\"]) con classe+sezione e combinazione tra parentesi quadre. Utile per l'analisi di una singola scuola." }
      },
      required: ["group_by"]
    )

    def self.call(group_by:, grado: nil, filiera: nil, area: nil, provincia: nil, comune: nil, regione: nil, classe: nil, editore: nil, disciplina: nil, titolo: nil, isbn: nil, scuola: nil, codice_scuola: nil, combinazione: nil, coefficiente: 17, order_by: "classi_count", offset: 0, limit: 50, solo_144: false, include_sezioni: false, server_context:, **_params)
      with_current(server_context) do
        filters = {
          area: area, provincia: provincia, comune: comune, regione: regione, classe: classe,
          editore: editore, disciplina: disciplina, titolo: titolo, isbn: isbn,
          combinazione: combinazione, scuola: scuola, codice_scuola: codice_scuola
        }.compact_blank

        query = ::Stats::NewAdozioniQuery.new(
          filters: filters,
          group_by: group_by.split(",").map(&:strip),
          coefficiente: coefficiente.to_i,
          order_by: order_by.to_sym,
          offset: offset.to_i,
          limit: limit.to_i,
          solo_144: solo_144 == true || solo_144 == "true",
          grado: grado,
          filiera: filiera,
          include_sezioni: include_sezioni == true || include_sezioni == "true"
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
