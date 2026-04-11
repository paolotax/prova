module MCPTools
  class DocumentiList < Base
    tool_name "documenti_list"
    description "Lista documenti (ordini, fatture, DDT). Filtri per ricerca, causale, tipo destinatario, stato."

    annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true)

    input_schema(
      type: "object",
      properties: {
        search: { type: "string", description: "Cerca per cliente, referente" },
        numero_documento: { type: "string", description: "Cerca per numero documento (es. 12, 2026/001)" },
        causale: { type: "string", description: "Filtra per causale: Ordine Scuola, Ordine Cliente, TD01, TD04, DDT, Campionario, saggi" },
        clientable_type: { type: "string", description: "Filtra per tipo: Scuola, Cliente" },
        stato: { type: "string", description: "Filtra per stato: attivi (default), completati, da_consegnare, da_pagare, tutti" },
        anno: { type: "integer", description: "Filtra per anno documento (es. 2026)" },
        data_inizio: { type: "string", description: "Data inizio range (YYYY-MM-DD)" },
        data_fine: { type: "string", description: "Data fine range (YYYY-MM-DD)" },
        tipo_pagamento: { type: "string", description: "Filtra per tipo pagamento" },
        libro_id: { type: "integer", description: "Filtra documenti che contengono questo libro (ID)" },
        libro_isbn: { type: "string", description: "Filtra documenti che contengono un libro per ISBN" },
        libro_categoria: { type: "string", description: "Filtra documenti con libri di questa categoria (es. vacanze, parascolastico)" },
        include_righe: { type: "boolean", description: "Se true, include le righe di ogni documento (default: false)" },
        sorted_by: { type: "string", description: "Ordinamento: data_documento (default), per_cliente" },
        offset: { type: "integer", description: "Salta i primi N risultati (per paginazione)" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    def self.call(search: nil, numero_documento: nil, causale: nil, clientable_type: nil, stato: nil, anno: nil, data_inizio: nil, data_fine: nil, tipo_pagamento: nil, libro_id: nil, libro_isbn: nil, libro_categoria: nil, include_righe: nil, sorted_by: nil, offset: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        scope = Current.account.documenti.solo_padri.includes(:causale, :clientable, entry: [:goldness, :closure])
        scope = scope.search_docs(search) if search.present?
        scope = scope.where("documenti.numero_documento ILIKE ?", "%#{numero_documento}%") if numero_documento.present?
        scope = scope.joins(:causale).where(causali: { causale: causale }) if causale.present?
        scope = scope.where(clientable_type: clientable_type) if clientable_type.present?
        scope = scope.where("EXTRACT(YEAR FROM data_documento) = ?", anno) if anno.present?
        scope = scope.where("data_documento >= ?", data_inizio) if data_inizio.present?
        scope = scope.where("data_documento <= ?", data_fine) if data_fine.present?
        scope = scope.joins(:pagamento).where(pagamenti: { tipo_pagamento: tipo_pagamento }) if tipo_pagamento.present?

        # Filtri per libro (subquery per evitare conflitto con eager loading :clientable)
        if libro_id.present?
          scope = scope.where(id: DocumentoRiga.where(riga: Riga.where(libro_id: libro_id)).select(:documento_id))
        end
        if libro_isbn.present?
          scope = scope.where(id: DocumentoRiga.joins(riga: :libro).where(libri: { codice_isbn: libro_isbn }).select(:documento_id))
        end
        if libro_categoria.present?
          scope = scope.where(id: DocumentoRiga.joins(riga: { libro: :categoria }).where(categorie: { nome_categoria: libro_categoria }).select(:documento_id))
        end

        case stato.to_s
        when "attivi"        then scope = scope.attivi
        when "completati"    then scope = scope.completati
        when "da_consegnare" then scope = scope.attivi.where.missing(:consegna)
        when "da_pagare"     then scope = scope.attivi.where.missing(:pagamento)
        when "tutti"         then nil
        else scope = scope.attivi
        end

        # Subquery per DISTINCT (evita duplicati da join righe/libri)
        ids = scope.reorder(nil).select("documenti.id").distinct
        eager = [:causale, :clientable, :consegna, :pagamento, entry: [:goldness, :closure]]
        eager << { documento_righe: { riga: :libro } } if include_righe
        result = Current.account.documenti.where(id: ids).includes(*eager)

        result = case sorted_by.to_s
                 when "per_cliente"
                   result.joins("LEFT JOIN scuole ON documenti.clientable_type = 'Scuola' AND documenti.clientable_id = scuole.id")
                        .joins("LEFT JOIN clienti ON documenti.clientable_type = 'Cliente' AND documenti.clientable_id = clienti.id")
                        .order(Arel.sql("COALESCE(scuole.denominazione, clienti.denominazione)"), data_documento: :desc)
                 else
                   result.order(data_documento: :desc, numero_documento: :desc)
                 end

        documenti = result.offset((offset || 0).to_i).limit((limit || 50).to_i.clamp(1, 200))

        response = { results: documenti.map { |d| format_documento(d, include_righe: include_righe) }, count: documenti.size }
        MCP::Tool::Response.new([{ type: "text", text: response.to_json }])
      end
    end

    def self.format_documento(doc, include_righe: false)
      result = {
        id: doc.id, numero_documento: doc.numero_documento, data_documento: doc.data_documento,
        causale: doc.causale&.causale, totale_cents: doc.totale_cents, totale_copie: doc.totale_copie,
        clientable_type: doc.clientable_type, clientable_display: doc.clientable&.denominazione,
        clientable_value: doc.clientable ? "#{doc.clientable_type}:#{doc.clientable_id}" : nil,
        golden: doc.golden?, closed: doc.closed?,
        consegnato: doc.consegnato_il.present?, consegnato_il: doc.consegnato_il,
        pagato: doc.pagato_il.present?, pagato_il: doc.pagato_il, tipo_pagamento: doc.tipo_pagamento
      }
      if include_righe
        result[:righe] = doc.documento_righe.map { |dr|
          r = dr.riga
          { libro_id: r.libro_id, codice_isbn: r.libro&.codice_isbn, titolo: r.libro&.titolo,
            quantita: r.quantita, prezzo_cents: r.prezzo_cents, sconto: r.sconto, importo_cents: r.importo_cents }
        }
      end
      result
    end
  end
end
