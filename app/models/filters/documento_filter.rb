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
      scope = filtered_scope
      scope = apply_stato_documento(scope)
      apply_ordering(scope)
    end

    alias_method :results, :documenti

    # Conteggi per i tab di stato sopra la tabella.
    # Calcolati sullo scope già filtrato dagli altri filtri (ricerca, causale...)
    # ma PRIMA del filtro di stato, così i numeri riflettono cosa si vedrebbe
    # cliccando ciascun tab.
    def stato_counts
      base = filtered_scope
      {
        "attivi"        => base.attivi.count,
        "da_consegnare" => base.attivi.where.missing(:consegna).count,
        "da_pagare"     => base.attivi.where.missing(:pagamento).count,
        "completati"    => base.completati.count,
        "tutti"         => base.count
      }
    end

    private

    # Scope con tutti i filtri tranne stato_documento e ordinamento.
    def filtered_scope
      target_account = account || Current.account
      result = target_account.documenti
        .solo_padri
        .joins("left outer join scuole on documenti.clientable_type = 'Scuola' and documenti.clientable_id = scuole.id")
        .joins("left outer join clienti on documenti.clientable_type = 'Cliente' and documenti.clientable_id = clienti.id")
        .joins("left outer join classi on documenti.clientable_type = 'Classe' and documenti.clientable_id = classi.id")
        .joins("left outer join persone on documenti.clientable_type = 'Persona' and documenti.clientable_id = persone.id")
        .joins("left outer join scuole scuole_clientable on scuole_clientable.id = coalesce(classi.scuola_id, persone.scuola_id)")
        .includes(:causale, :clientable, :consegna, :pagamento, :righe,
                  entry: [:column, :goldness, :closure, :not_now],
                  documento_righe: [riga: :libro],
                  documenti_derivati: :causale)

      # Scoping per membership: member vede solo documenti delle sue scuole
      unless Current.admin?
        scuola_ids = Current.membership&.scuola_ids || []
        result = result.where(clientable_type: "Scuola", clientable_id: scuola_ids)
      end

      result = apply_terms(result)

      result = result.where(causale_id: causali) if causali.present?
      result = result.joins(:pagamento).where(pagamenti: { tipo_pagamento: tipi_pagamento }) if tipi_pagamento.present?
      result = result.where(clientable_type: clientable_type) if clientable_type.present?
      result = result.where("EXTRACT(YEAR FROM data_documento) = ?", anno) if anno.present?
      result = result.joins(:consegna) if consegnati.present?
      result = result.joins(:pagamento) if pagati.present?

      result
    end

    # Ricerca testuale estesa: denominazione cliente/scuola, referente,
    # numero documento (se il termine è numerico) e titolo/ISBN libro nelle righe.
    def apply_terms(scope)
      return scope unless terms.present?

      term = terms.first
      like = "%#{term}%"
      clauses = [
        "scuole.denominazione ILIKE :like OR clienti.denominazione ILIKE :like OR documenti.referente ILIKE :like " \
          "OR scuole_clientable.denominazione ILIKE :like " \
          "OR persone.nome ILIKE :like OR persone.cognome ILIKE :like",
        "EXISTS (SELECT 1 FROM documento_righe dr " \
          "JOIN righe r ON r.id = dr.riga_id " \
          "JOIN libri l ON l.id = r.libro_id " \
          "WHERE dr.documento_id = documenti.id " \
          "AND (l.titolo ILIKE :like OR l.codice_isbn ILIKE :like))"
      ]
      binds = { like: like }

      if term.match?(/\A\d+\z/)
        clauses << "documenti.numero_documento = :num"
        binds[:num] = term.to_i
      end

      scope.where(clauses.join(" OR "), binds)
    end

    def apply_stato_documento(scope)
      case stato_documento
      when "da_consegnare" then scope.attivi.where.missing(:consegna)
      when "da_pagare"     then scope.attivi.where.missing(:pagamento)
      when "completati"    then scope.completati
      when "tutti"         then scope
      else                      scope.attivi # "attivi" e default
      end
    end

    def apply_ordering(scope)
      case sorted_by.to_s
      when "per_cliente"
        scope.order(
          Arel.sql(Documento::GOLDEN_SORT_SQL),
          Arel.sql("EXTRACT(YEAR FROM documenti.data_documento) DESC"),
          Arel.sql("COALESCE(scuole.denominazione, clienti.denominazione, scuole_clientable.denominazione)"),
          data_documento: :desc,
          numero_documento: :desc
        )
      else
        scope.order(
          Arel.sql(Documento::GOLDEN_SORT_SQL),
          data_documento: :desc,
          numero_documento: :desc,
          causale_id: :desc
        )
      end
    end
  end
end
