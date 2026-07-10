class VenditeController < ApplicationController
  before_action :authenticate_user!

  GROUP_DIMENSIONS = {
    "categoria"  => { sql: "categorie.nome_categoria", joins: { libro: :categoria } },
    "editore"    => { sql: "editori.editore",          joins: { libro: :editore } },
    "classe"     => { sql: "libri.classe",             joins: nil },
    "disciplina" => { sql: "libri.disciplina",         joins: nil }
  }.freeze

  IMPORTO_SQL = "SUM((righe.prezzo_cents - righe.prezzo_cents * COALESCE(righe.sconto, 0) / 100.0) * righe.quantita)".freeze

  def index
    doc_scope = build_doc_scope
    righe_scope = build_righe_scope(doc_scope)

    skip = (params[:offset] || 0).to_i
    max = (params[:limit] || 50).to_i.clamp(1, 200)

    results = if params[:group_by].present?
      aggregate_by_dimensions(righe_scope, params[:group_by], params[:sorted_by], skip, max)
    else
      aggregate_by_libro(righe_scope, doc_scope, params[:sorted_by], skip, max)
    end

    respond_to do |format|
      format.json { render json: { ok: true, data: results, count: results.size } }
    end
  end

  private

  def build_doc_scope
    scope = Current.account.documenti.solo_padri
    scope = scope.where("EXTRACT(YEAR FROM data_documento) = ?", params[:anno]) if params[:anno].present?
    scope = scope.where("data_documento >= ?", params[:data_inizio]) if params[:data_inizio].present?
    scope = scope.where("data_documento <= ?", params[:data_fine]) if params[:data_fine].present?
    scope = scope.joins(:causale).where(causali: { causale: params[:causale] }) if params[:causale].present?
    scope = scope.joins(:causale).where(causali: { tipo_movimento: :vendita }) unless params[:include_non_vendite].present?
    scope = scope.where(clientable_type: params[:clientable_type]) if params[:clientable_type].present?

    case params[:stato].to_s
    when "attivi"        then scope.attivi
    when "completati"    then scope.completati
    when "da_consegnare" then scope.attivi.where.missing(:consegne).joins(:causale).where(causali: { gestione_consegna: true })
    when "da_pagare"     then scope.attivi.where.missing(:pagamenti).joins(:causale).where(causali: { gestione_pagamento: true })
    when "tutti"         then scope
    else scope.attivi
    end
  end

  def build_righe_scope(doc_scope)
    scope = Riga.joins(:documento_righe)
                .where(documento_righe: { documento_id: doc_scope.select(:id) })
                .joins(:libro)
    scope = scope.where(libri: { id: params[:libro_id] }) if params[:libro_id].present?
    scope = scope.where(libri: { codice_isbn: params[:libro_isbn] }) if params[:libro_isbn].present?
    if params[:libro_categoria].present?
      scope = scope.joins(libro: :categoria).where(categorie: { nome_categoria: params[:libro_categoria] })
    end
    if params[:libro_editore].present?
      scope = scope.joins(libro: :editore).where("editori.editore ILIKE ?", "%#{params[:libro_editore]}%")
    end
    scope
  end

  def exec_rows(relation)
    ActiveRecord::Base.connection.select_all(relation.to_sql).to_a
  end

  def aggregate_by_dimensions(righe_scope, group_by_str, sorted_by, skip, max)
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

  def aggregate_by_libro(righe_scope, doc_scope, sorted_by, skip, max)
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

  def fetch_destinatari(doc_scope, libro_ids)
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
