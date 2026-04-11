class VenditeController < ApplicationController
  before_action :authenticate_user!

  def index
    doc_scope = Current.account.documenti.solo_padri

    # Filtri documento
    doc_scope = doc_scope.where("EXTRACT(YEAR FROM data_documento) = ?", params[:anno]) if params[:anno].present?
    doc_scope = doc_scope.where("data_documento >= ?", params[:data_inizio]) if params[:data_inizio].present?
    doc_scope = doc_scope.where("data_documento <= ?", params[:data_fine]) if params[:data_fine].present?
    doc_scope = doc_scope.joins(:causale).where(causali: { causale: params[:causale] }) if params[:causale].present?
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
        "SUM(righe.importo_cents) AS totale_importo_cents",
        "COUNT(DISTINCT documento_righe.documento_id) AS documenti_count"
      )

    # Ordinamento
    @vendite = case params[:sorted_by].to_s
               when "importo" then @vendite.order(Arel.sql("SUM(righe.importo_cents) DESC"))
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
