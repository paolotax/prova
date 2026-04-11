class VenditeController < ApplicationController
  before_action :authenticate_user!

  def index
    doc_scope = Current.account.documenti.solo_padri

    # Filtri documento
    doc_scope = doc_scope.where("EXTRACT(YEAR FROM data_documento) = ?", params[:anno]) if params[:anno].present?
    doc_scope = doc_scope.where("data_documento >= ?", params[:data_inizio]) if params[:data_inizio].present?
    doc_scope = doc_scope.where("data_documento <= ?", params[:data_fine]) if params[:data_fine].present?
    doc_scope = doc_scope.joins(:causale).where(causali: { causale: params[:causale] }) if params[:causale].present?

    # Default: solo causali con tipo_movimento = vendita
    unless params[:include_non_vendite].present?
      doc_scope = doc_scope.joins(:causale).where(causali: { tipo_movimento: :vendita })
    end

    doc_scope = doc_scope.where(clientable_type: params[:clientable_type]) if params[:clientable_type].present?

    case params[:stato].to_s
    when "attivi"        then doc_scope = doc_scope.attivi
    when "completati"    then doc_scope = doc_scope.completati
    when "da_consegnare" then doc_scope = doc_scope.attivi.where.missing(:consegna)
    when "da_pagare"     then doc_scope = doc_scope.attivi.where.missing(:pagamento)
    when "tutti"         then nil
    else doc_scope = doc_scope.attivi
    end

    # Righe dei documenti filtrati
    righe_scope = Riga.joins(:documento_righe)
                      .where(documento_righe: { documento_id: doc_scope.select(:id) })
                      .joins(:libro)

    # Filtri libro
    righe_scope = righe_scope.where(libri: { id: params[:libro_id] }) if params[:libro_id].present?
    righe_scope = righe_scope.where(libri: { codice_isbn: params[:libro_isbn] }) if params[:libro_isbn].present?
    if params[:libro_categoria].present?
      righe_scope = righe_scope.joins(libro: :categoria).where(categorie: { nome_categoria: params[:libro_categoria] })
    end
    if params[:libro_editore].present?
      righe_scope = righe_scope.joins(libro: :editore).where("editori.editore ILIKE ?", "%#{params[:libro_editore]}%")
    end

    # Aggregazione per libro
    @vendite = righe_scope
      .group("libri.id", "libri.titolo", "libri.codice_isbn")
      .select(
        "libri.id AS libro_id",
        "libri.titolo",
        "libri.codice_isbn",
        "SUM(righe.quantita) AS totale_copie",
        "SUM((righe.prezzo_cents - righe.prezzo_cents * COALESCE(righe.sconto, 0) / 100.0) * righe.quantita)::bigint AS totale_importo_cents",
        "COUNT(DISTINCT documento_righe.documento_id) AS documenti_count"
      )

    # Ordinamento
    @vendite = case params[:sorted_by].to_s
               when "importo" then @vendite.order(Arel.sql("SUM((righe.prezzo_cents - righe.prezzo_cents * COALESCE(righe.sconto, 0) / 100.0) * righe.quantita) DESC"))
               when "titolo"  then @vendite.order("libri.titolo")
               else @vendite.order(Arel.sql("SUM(righe.quantita) DESC"))
               end

    skip = (params[:offset] || 0).to_i
    max = (params[:limit] || 50).to_i.clamp(1, 200)
    @vendite = @vendite.offset(skip).limit(max)

    # Destinatari per libro
    libro_ids = @vendite.map(&:libro_id)
    @destinatari = fetch_destinatari(doc_scope, libro_ids)

    respond_to do |format|
      format.json do
        results = @vendite.map do |row|
          {
            libro_id: row.libro_id,
            titolo: row.titolo,
            codice_isbn: row.codice_isbn,
            totale_copie: row.totale_copie.to_i,
            totale_importo_cents: row.totale_importo_cents.to_i,
            documenti_count: row.documenti_count.to_i,
            destinatari: @destinatari[row.libro_id] || []
          }
        end
        render json: { ok: true, data: results, count: results.size }
      end
    end
  end

  private

  def fetch_destinatari(doc_scope, libro_ids)
    return {} if libro_ids.empty?

    rows = DocumentoRiga
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
        "SUM((righe.prezzo_cents - righe.prezzo_cents * COALESCE(righe.sconto, 0) / 100.0) * righe.quantita)::bigint AS importo_cents",
        "consegne.consegnato_il IS NOT NULL AS consegnato",
        "consegne.consegnato_il",
        "pagamenti.pagato_il IS NOT NULL AS pagato",
        "pagamenti.pagato_il",
        "pagamenti.tipo_pagamento"
      )

    rows.group_by(&:libro_id).transform_values do |rs|
      rs.map do |r|
        {
          nome: r.nome,
          clientable_value: r.clientable_value,
          documento_id: r.documento_id,
          numero_documento: r.numero_documento,
          copie: r.copie.to_i,
          importo_cents: r.importo_cents.to_i,
          referente: r.referente,
          note: r.note,
          consegnato: r.consegnato,
          consegnato_il: r.consegnato_il,
          pagato: r.pagato,
          pagato_il: r.pagato_il,
          tipo_pagamento: r.tipo_pagamento
        }
      end.sort_by { |d| d[:nome].to_s }
    end
  end
end
