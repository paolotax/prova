module MCPTools
  class VenditePerLibro < Base
    tool_name "vendite_per_libro"
    description "Aggregazione vendite: per libro (default) o raggruppata per categoria/editore/classe/disciplina con group_by. Risponde a 'quante copie ho venduto?', 'quali editori vendono di più?', 'cosa devo ancora consegnare?'."

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
        include_non_vendite: { type: "boolean", description: "Se true, include anche campionari, saggi, carichi (default: solo vendite)" },
        clientable_type: { type: "string", description: "Filtra per tipo destinatario: Scuola, Cliente" },
        stato: { type: "string", description: "Filtra per stato documento: attivi (default), completati, da_consegnare, da_pagare, tutti" },
        group_by: { type: "string", description: "Aggrega per dimensioni separate da virgola: categoria, editore, classe, disciplina. Es. 'editore' o 'editore,categoria'. Se presente, ignora il dettaglio per libro." },
        sorted_by: { type: "string", description: "Ordinamento: copie (default), importo, titolo" },
        offset: { type: "integer", description: "Salta i primi N risultati (per paginazione)" },
        limit: { type: "integer", description: "Max risultati (1-200, default 50)" }
      }
    )

    # Whitelist dimensioni group_by con metadata
    GROUP_DIMENSIONS = {
      "categoria"  => { sql: "categorie.nome_categoria", joins: { libro: :categoria } },
      "editore"    => { sql: "editori.editore",          joins: { libro: :editore } },
      "classe"     => { sql: "libri.classe",             joins: nil },
      "disciplina" => { sql: "libri.disciplina",         joins: nil }
    }.freeze

    IMPORTO_SQL = "SUM((righe.prezzo_cents - righe.prezzo_cents * COALESCE(righe.sconto, 0) / 100.0) * righe.quantita)".freeze

    def self.call(anno: nil, data_inizio: nil, data_fine: nil, libro_id: nil, libro_isbn: nil,
                  libro_categoria: nil, libro_editore: nil, causale: nil, include_non_vendite: nil,
                  clientable_type: nil, stato: nil, group_by: nil, sorted_by: nil,
                  offset: nil, limit: nil, server_context:, **_params)
      with_current(server_context) do
        doc_scope = build_doc_scope(
          anno: anno, data_inizio: data_inizio, data_fine: data_fine,
          causale: causale, include_non_vendite: include_non_vendite,
          clientable_type: clientable_type, stato: stato
        )

        righe_scope = build_righe_scope(doc_scope,
          libro_id: libro_id, libro_isbn: libro_isbn,
          libro_categoria: libro_categoria, libro_editore: libro_editore
        )

        skip = (offset || 0).to_i
        max = (limit || 50).to_i.clamp(1, 200)

        results = if group_by.present?
          aggregate_by_dimensions(righe_scope, group_by, sorted_by, skip, max)
        else
          aggregate_by_libro(righe_scope, doc_scope, sorted_by, skip, max)
        end

        MCP::Tool::Response.new([{ type: "text", text: { results: results, count: results.size }.to_json }])
      end
    end

    private

    def self.build_doc_scope(anno:, data_inizio:, data_fine:, causale:, include_non_vendite:,
                              clientable_type:, stato:)
      scope = Current.account.documenti.solo_padri
      scope = scope.where("EXTRACT(YEAR FROM data_documento) = ?", anno) if anno.present?
      scope = scope.where("data_documento >= ?", data_inizio) if data_inizio.present?
      scope = scope.where("data_documento <= ?", data_fine) if data_fine.present?
      scope = scope.joins(:causale).where(causali: { causale: causale }) if causale.present?
      scope = scope.joins(:causale).where(causali: { tipo_movimento: :vendita }) unless include_non_vendite
      scope = scope.where(clientable_type: clientable_type) if clientable_type.present?

      case stato.to_s
      when "attivi"        then scope.attivi
      when "completati"    then scope.completati
      when "da_consegnare" then scope.attivi.where.missing(:consegne)
      when "da_pagare"     then scope.attivi.where.missing(:pagamento)
      when "tutti"         then scope
      else scope.attivi
      end
    end

    def self.build_righe_scope(doc_scope, libro_id:, libro_isbn:, libro_categoria:, libro_editore:)
      scope = Riga.joins(:documento_righe)
                  .where(documento_righe: { documento_id: doc_scope.select(:id) })
                  .joins(:libro)
      scope = scope.where(libri: { id: libro_id }) if libro_id.present?
      scope = scope.where(libri: { codice_isbn: libro_isbn }) if libro_isbn.present?
      if libro_categoria.present?
        scope = scope.joins(libro: :categoria).where(categorie: { nome_categoria: libro_categoria })
      end
      if libro_editore.present?
        scope = scope.joins(libro: :editore).where("editori.editore ILIKE ?", "%#{libro_editore}%")
      end
      scope
    end

    # Esegue la relation come SQL grezzo, restituisce array di hash (bypassa model materialization)
    def self.exec_rows(relation)
      ActiveRecord::Base.connection.select_all(relation.to_sql).to_a
    end

    # Aggregazione per dimensioni (group_by)
    def self.aggregate_by_dimensions(righe_scope, group_by_str, sorted_by, skip, max)
      dims = group_by_str.split(",").map(&:strip) & GROUP_DIMENSIONS.keys
      return [] if dims.empty?

      dims.each do |dim|
        join = GROUP_DIMENSIONS[dim][:joins]
        righe_scope = righe_scope.joins(join) if join
      end

      group_cols = dims.map { |d| GROUP_DIMENSIONS[d][:sql] }
      select_aliases = dims.map { |d| "#{GROUP_DIMENSIONS[d][:sql]} AS #{d}" }

      aggregated = righe_scope
        .group(*group_cols)
        .select(
          *select_aliases,
          "SUM(righe.quantita) AS copie",
          "#{IMPORTO_SQL}::bigint AS importo_cents",
          "COUNT(DISTINCT righe.libro_id) AS libri_count",
          "COUNT(DISTINCT documento_righe.documento_id) AS documenti_count"
        )

      aggregated = case sorted_by.to_s
                   when "importo" then aggregated.order(Arel.sql("#{IMPORTO_SQL} DESC"))
                   when "titolo"  then aggregated.order(*group_cols)
                   else aggregated.order(Arel.sql("SUM(righe.quantita) DESC"))
                   end

      rows = exec_rows(aggregated.offset(skip).limit(max))

      rows.map do |row|
        result = dims.each_with_object({}) { |d, h| h[d.to_sym] = row[d] }
        result[:copie] = row["copie"].to_i
        result[:importo_cents] = row["importo_cents"].to_i
        result[:libri_count] = row["libri_count"].to_i
        result[:documenti_count] = row["documenti_count"].to_i
        result
      end
    end

    # Aggregazione per libro (default) — con destinatari dettagliati
    def self.aggregate_by_libro(righe_scope, doc_scope, sorted_by, skip, max)
      aggregated = righe_scope
        .group("libri.id", "libri.titolo", "libri.codice_isbn")
        .select(
          "libri.id AS libro_id",
          "libri.titolo AS libro_titolo",
          "libri.codice_isbn AS libro_codice_isbn",
          "SUM(righe.quantita) AS totale_copie",
          "#{IMPORTO_SQL}::bigint AS totale_importo_cents",
          "COUNT(DISTINCT documento_righe.documento_id) AS documenti_count"
        )

      aggregated = case sorted_by.to_s
                   when "importo" then aggregated.order(Arel.sql("#{IMPORTO_SQL} DESC"))
                   when "titolo"  then aggregated.order("libri.titolo")
                   else aggregated.order(Arel.sql("SUM(righe.quantita) DESC"))
                   end

      rows = exec_rows(aggregated.offset(skip).limit(max))
      libro_ids = rows.map { |r| r["libro_id"] }
      destinatari = fetch_destinatari(doc_scope, libro_ids)

      rows.map do |row|
        {
          libro_id: row["libro_id"],
          titolo: row["libro_titolo"],
          codice_isbn: row["libro_codice_isbn"],
          totale_copie: row["totale_copie"].to_i,
          totale_importo_cents: row["totale_importo_cents"].to_i,
          documenti_count: row["documenti_count"].to_i,
          destinatari: destinatari[row["libro_id"]] || []
        }
      end
    end

    # Dettaglio destinatari per libro: una entry per documento
    def self.fetch_destinatari(doc_scope, libro_ids)
      return {} if libro_ids.empty?

      relation = DocumentoRiga
        .joins(:documento, :riga)
        .joins("LEFT JOIN scuole ON documenti.clientable_type = 'Scuola' AND documenti.clientable_id = scuole.id")
        .joins("LEFT JOIN clienti ON documenti.clientable_type = 'Cliente' AND documenti.clientable_id = clienti.id")
        .joins("LEFT JOIN consegne ON consegne.consegnabile_type = 'Documento' AND consegne.consegnabile_id = documenti.id")
        .joins("LEFT JOIN pagamenti ON pagamenti.pagabile_type = 'Documento' AND pagamenti.pagabile_id = documenti.id")
        .where(documento_id: doc_scope.select(:id))
        .where(righe: { libro_id: libro_ids })
        .group("righe.libro_id", "documenti.id", "scuole.denominazione", "clienti.denominazione",
               "documenti.clientable_type", "documenti.clientable_id",
               "documenti.numero_documento", "documenti.referente", "documenti.note",
               "consegne.consegnato_il", "pagamenti.pagato_il", "pagamenti.tipo_pagamento")
        .select(
          "righe.libro_id",
          "documenti.id AS documento_id",
          "COALESCE(scuole.denominazione, clienti.denominazione) AS nome",
          "documenti.clientable_type || ':' || documenti.clientable_id AS clientable_value",
          "documenti.numero_documento",
          "documenti.referente",
          "documenti.note",
          "SUM(righe.quantita) AS copie",
          "#{IMPORTO_SQL}::bigint AS importo_cents",
          "consegne.consegnato_il IS NOT NULL AS consegnato",
          "consegne.consegnato_il",
          "pagamenti.pagato_il IS NOT NULL AS pagato",
          "pagamenti.pagato_il",
          "pagamenti.tipo_pagamento"
        )

      rows = exec_rows(relation)

      rows.group_by { |r| r["libro_id"] }.transform_values do |rs|
        rs.map do |r|
          {
            nome: r["nome"],
            clientable_value: r["clientable_value"],
            documento_id: r["documento_id"],
            numero_documento: r["numero_documento"],
            copie: r["copie"].to_i,
            importo_cents: r["importo_cents"].to_i,
            referente: r["referente"],
            note: r["note"],
            consegnato: r["consegnato"],
            consegnato_il: r["consegnato_il"],
            pagato: r["pagato"],
            pagato_il: r["pagato_il"],
            tipo_pagamento: r["tipo_pagamento"]
          }
        end.sort_by { |d| d[:nome].to_s }
      end
    end
  end
end
