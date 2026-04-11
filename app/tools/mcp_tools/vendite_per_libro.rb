module MCPTools
  class VenditePerLibro < Base
    tool_name "vendite_per_libro"
    description "Aggregazione vendite per libro: copie, importo, scuole/clienti, documenti. Risponde a 'quante copie ho venduto?', 'quali scuole hanno preso vacanze?', 'cosa devo ancora consegnare?'."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        anno: { type: "integer", description: "Filtra per anno documento (es. 2026)" },
        data_inizio: { type: "string", description: "Data inizio range (YYYY-MM-DD)" },
        data_fine: { type: "string", description: "Data fine range (YYYY-MM-DD)" },
        libro_id: { type: "integer", description: "Filtra per libro specifico (ID)" },
        libro_isbn: { type: "string", description: "Filtra per ISBN libro" },
        libro_categoria: { type: "string", description: "Filtra per categoria libro (es. vacanze, parascolastico)" },
        libro_editore: { type: "string", description: "Filtra per editore (es. GIUNTI SCUOLA)" },
        causale: { type: "string", description: "Filtra per causale documento (es. Ordine Scuola)" },
        clientable_type: { type: "string", description: "Filtra per tipo destinatario: Scuola, Cliente" },
        stato: { type: "string", description: "Filtra per stato documento: attivi (default), completati, da_consegnare, da_pagare, tutti" },
        sorted_by: { type: "string", description: "Ordinamento: copie (default), importo, titolo" },
        offset: { type: "integer", description: "Salta i primi N risultati (per paginazione)" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    def self.call(anno: nil, data_inizio: nil, data_fine: nil, libro_id: nil, libro_isbn: nil,
                  libro_categoria: nil, libro_editore: nil, causale: nil, clientable_type: nil,
                  stato: nil, sorted_by: nil, offset: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        # Base: documenti dell'account, solo padri
        doc_scope = Current.account.documenti.solo_padri

        # Filtri documento
        doc_scope = doc_scope.where("EXTRACT(YEAR FROM data_documento) = ?", anno) if anno.present?
        doc_scope = doc_scope.where("data_documento >= ?", data_inizio) if data_inizio.present?
        doc_scope = doc_scope.where("data_documento <= ?", data_fine) if data_fine.present?
        doc_scope = doc_scope.joins(:causale).where(causali: { causale: causale }) if causale.present?
        doc_scope = doc_scope.where(clientable_type: clientable_type) if clientable_type.present?

        case stato.to_s
        when "attivi"        then doc_scope = doc_scope.attivi
        when "completati"    then doc_scope = doc_scope.completati
        when "da_consegnare" then doc_scope = doc_scope.attivi.where.missing(:consegna)
        when "da_pagare"     then doc_scope = doc_scope.attivi.where.missing(:pagamento)
        when "tutti"         then nil
        else doc_scope = doc_scope.attivi
        end

        # Righe dei documenti filtrati
        righe_scope = Riga.joins(:documento_riga)
                          .where(documento_righe: { documento_id: doc_scope.select(:id) })
                          .joins(:libro)

        # Filtri libro
        righe_scope = righe_scope.where(libri: { id: libro_id }) if libro_id.present?
        righe_scope = righe_scope.where(libri: { codice_isbn: libro_isbn }) if libro_isbn.present?
        if libro_categoria.present?
          righe_scope = righe_scope.joins(libro: :categoria).where(categorie: { nome_categoria: libro_categoria })
        end
        if libro_editore.present?
          righe_scope = righe_scope.joins(libro: :editore).where("editori.editore ILIKE ?", "%#{libro_editore}%")
        end

        # Aggregazione per libro
        aggregated = righe_scope
          .group("libri.id", "libri.titolo", "libri.codice_isbn")
          .select(
            "libri.id AS libro_id",
            "libri.titolo",
            "libri.codice_isbn",
            "SUM(righe.quantita) AS totale_copie",
            "SUM(righe.importo_cents) AS totale_importo_cents",
            "COUNT(DISTINCT documento_righe.documento_id) AS documenti_count"
          )

        # Ordinamento
        aggregated = case sorted_by.to_s
                     when "importo" then aggregated.order(Arel.sql("SUM(righe.importo_cents) DESC"))
                     when "titolo"  then aggregated.order("libri.titolo")
                     else aggregated.order(Arel.sql("SUM(righe.quantita) DESC"))
                     end

        skip = (offset || 0).to_i
        max = (limit || 50).to_i.clamp(1, 200)
        rows = aggregated.offset(skip).limit(max)

        # Per ogni libro, raccogliamo i destinatari
        libro_ids = rows.map(&:libro_id)
        destinatari = fetch_destinatari(doc_scope, libro_ids)

        results = rows.map do |row|
          {
            libro_id: row.libro_id,
            titolo: row.titolo,
            codice_isbn: row.codice_isbn,
            totale_copie: row.totale_copie.to_i,
            totale_importo_cents: row.totale_importo_cents.to_i,
            documenti_count: row.documenti_count.to_i,
            destinatari: destinatari[row.libro_id] || []
          }
        end

        MCP::Tool::Response.new([{ type: "text", text: { results: results, count: results.size }.to_json }])
      end
    end

    private

    # Recupera i destinatari (scuole/clienti) per ogni libro
    def self.fetch_destinatari(doc_scope, libro_ids)
      return {} if libro_ids.empty?

      rows = DocumentoRiga
        .joins(:documento, :riga)
        .joins("LEFT JOIN scuole ON documenti.clientable_type = 'Scuola' AND documenti.clientable_id = scuole.id")
        .joins("LEFT JOIN clienti ON documenti.clientable_type = 'Cliente' AND documenti.clientable_id = clienti.id")
        .where(documento_id: doc_scope.select(:id))
        .where(righe: { libro_id: libro_ids })
        .select(
          "righe.libro_id",
          "COALESCE(scuole.denominazione, clienti.denominazione) AS destinatario"
        )
        .distinct

      rows.group_by(&:libro_id).transform_values { |rs| rs.map(&:destinatario).compact.sort }
    end
  end
end
