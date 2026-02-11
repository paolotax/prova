# == Schema Information
#
# Table name: filters
#
#  id            :uuid             not null, primary key
#  fields        :jsonb
#  params_digest :string
#  type          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid
#  creator_id    :bigint
#
# Indexes
#
#  index_filters_on_account_id              (account_id)
#  index_filters_on_creator_id              (creator_id)
#  index_filters_on_type_and_params_digest  (type,params_digest) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (creator_id => users.id)
#
module Filters
  class DocumentoFilter < Base
    include DocumentoFilter::Fields
    include DocumentoFilter::Summarized

    def documenti
      target_account = account || Current.account
      result = target_account.documenti
        .solo_padri
        .joins("left outer join scuole on documenti.clientable_type = 'Scuola' and documenti.clientable_id = scuole.id")
        .joins("left outer join clienti on documenti.clientable_type = 'Cliente' and documenti.clientable_id = clienti.id")
        .includes(:causale, :righe, documento_righe: [riga: :libro])

      # Text search
      if terms.present?
        search_term = "%#{terms.first}%"
        result = result.where(
          "scuole.denominazione ILIKE :term OR clienti.denominazione ILIKE :term OR documenti.referente ILIKE :term",
          term: search_term
        )
      end

      # Causale filter
      result = result.where(causale_id: causali) if causali.present?

      # Tipo pagamento filter (via Pagamento state record)
      result = result.joins(:pagamento).where(pagamenti: { tipo_pagamento: tipi_pagamento }) if tipi_pagamento.present?

      # Clientable type filter
      result = result.where(clientable_type: clientable_type) if clientable_type.present?

      # Anno filter
      if anno.present?
        result = result.where("EXTRACT(YEAR FROM data_documento) = ?", anno)
      end

      # Boolean filters (via state records)
      result = result.joins(:consegna) if consegnati.present?
      result = result.joins(:pagamento) if pagati.present?

      # Stato documento filter (attivi/da consegnare/da pagare/completati/tutti)
      case stato_documento
      when "attivi"
        result = result.attivi
      when "da_consegnare"
        result = result.attivi.where.missing(:consegna)
      when "da_pagare"
        result = result.attivi.where.missing(:pagamento)
      when "completati"
        result = result.completati
      when "tutti"
        # Nessun filtro su stato closure
        result
      else
        # Default: mostra solo documenti attivi (non chiusi)
        result = result.attivi
      end

      # Ordering (golden items first via subquery, then by date)
      result = result.order(
        Arel.sql(Documento::GOLDEN_SORT_SQL),
        data_documento: :desc,
        causale_id: :desc,
        numero_documento: :desc
      )
      result
    end

    alias_method :results, :documenti
  end
end
