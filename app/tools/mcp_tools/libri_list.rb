module MCPTools
  class LibriList < Base
    tool_name "libri_list"
    description "Lista libri del catalogo con ricerca per titolo/ISBN e filtro per categoria, editore, classe."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        query: { type: "string", description: "Cerca per titolo o ISBN" },
        categoria: { type: "string", description: "Filtra per categoria (es. vacanze, parascolastico, adozionale)" },
        editore: { type: "string", description: "Filtra per editore (es. GIUNTI SCUOLA)" },
        disciplina: { type: "string", description: "Filtra per disciplina" },
        classe: { type: "integer", description: "Filtra per classe (1-5)" },
        sorted_by: { type: "string", description: "Ordinamento: titolo (default), editore, categoria" },
        limit: { type: "integer", description: "Numero massimo di risultati (1-50, default 20)" }
      }
    )

    def self.call(query: nil, categoria: nil, editore: nil, disciplina: nil, classe: nil, sorted_by: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        max = (limit || 20).to_i.clamp(1, 50)
        scope = Current.account.libri.includes(:editore, :categoria)
        scope = scope.search_all_word(query) if query.present?
        scope = scope.joins(:categoria).where(categorie: { nome_categoria: categoria.downcase }) if categoria.present?
        scope = scope.joins(:editore).where("editori.editore ILIKE ?", "%#{editore}%") if editore.present?
        scope = scope.where("libri.disciplina ILIKE ?", "%#{disciplina}%") if disciplina.present?
        scope = scope.where(classe: classe) if classe.present?
        # Subquery per evitare DISTINCT + ORDER BY su colonne joined
        ids = scope.reorder(nil).distinct.pluck(:id)
        result = Current.account.libri.where(id: ids).includes(:editore, :categoria)

        case sorted_by.to_s
        when "editore"
          result = result.left_joins(:editore).order("editori.editore", "libri.titolo")
        when "categoria"
          result = result.left_joins(:categoria).order("categorie.nome_categoria", "libri.titolo")
        else
          result = result.order("libri.titolo")
        end
        libri = result.limit(max)

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
        prezzo_suggerito: libro.prezzo_suggerito_cents ? "%.2f" % (libro.prezzo_suggerito_cents / 100.0) : nil,
        editore: libro.editore&.editore,
        categoria: libro.categoria&.nome_categoria,
        disciplina: libro.disciplina,
        classe: libro.classe,
        collana: libro.collana
      }
    end
  end
end
