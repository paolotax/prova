module Filters
  module DocumentoFilterScopes
    extend FilterScopeable

    filter_scope :search, ->(search) {
      left_joins_clientable
      .joins("JOIN causali ON documenti.causale_id = causali.id")
      .where('scuole.denominazione ILIKE ?
              OR scuole.comune ILIKE ?
              OR clienti.denominazione ILIKE ?
              OR clienti.comune ILIKE ?
              OR causali.causale ILIKE ?',
      "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%")
    }

    filter_scope :search_libro, ->(search) { joins(documento_righe: [riga: :libro]).where("libri.titolo ILIKE ?", "%#{search}%").distinct }
    filter_scope :causale, ->(causale) { joins(:causale).where("causali.causale ILIKE ?", "%#{causale}%") }
    filter_scope :tipo_pagamento, ->(tipo_pagamento) {
      joins(:pagamento).where(pagamenti: { tipo_pagamento: tipo_pagamento })
    }

    filter_scope :ordina_per, ->(ordine) { order_by(ordine) }

    filter_scope :anno, ->(anno) { where('EXTRACT(YEAR FROM data_documento) = ?', anno) }

    filter_scope :consegnato_il, ->(data) {
      joins(:consegna).where('DATE(consegne.consegnato_il) = ?', data.to_date)
    }
    filter_scope :pagato_il, ->(data) {
      joins(:pagamento).where('DATE(pagamenti.pagato_il) = ?', data.to_date)
    }

    filter_scope :consegnati, ->(consegnati) {
      consegnati == 'si' ? joins(:consegna) : left_joins(:consegna).where(consegne: { id: nil })
    }
    filter_scope :pagati, ->(pagati) {
      pagati == 'si' ? joins(:pagamento) : left_joins(:pagamento).where(pagamenti: { id: nil })
    }

    filter_scope :nel_baule_del_giorno, ->(data) {
      sanitized_date = ActiveRecord::Base.connection.quote(data)

      union_sql = <<-SQL
        (
          SELECT DISTINCT documenti.*
          FROM documenti
          INNER JOIN tappe ON documenti.clientable_id = tappe.tappable_id
            AND documenti.clientable_type = tappe.tappable_type
          LEFT JOIN consegne ON documenti.id = consegne.consegnabile_id
            AND consegne.consegnabile_type = 'Documento'
          LEFT JOIN pagamenti ON documenti.id = pagamenti.pagabile_id
            AND pagamenti.pagabile_type = 'Documento'
          WHERE DATE(tappe.data_tappa) = #{sanitized_date}
            AND (consegne.id IS NULL OR pagamenti.id IS NULL)
        )
        UNION
        (
          SELECT DISTINCT documenti.*
          FROM documenti
          INNER JOIN tappe ON documenti.clientable_id = tappe.tappable_id
            AND documenti.clientable_type = tappe.tappable_type
          LEFT JOIN consegne ON documenti.id = consegne.consegnabile_id
            AND consegne.consegnabile_type = 'Documento'
          LEFT JOIN pagamenti ON documenti.id = pagamenti.pagabile_id
            AND pagamenti.pagabile_type = 'Documento'
          WHERE (DATE(consegne.consegnato_il) = #{sanitized_date} OR DATE(pagamenti.pagato_il) = #{sanitized_date})
        )
      SQL

      from("(#{union_sql}) AS documenti")
    }


    filter_scope :tappe_del_giorno, ->(data) {
      joins("INNER JOIN tappe ON documenti.clientable_id = tappe.tappable_id
             AND documenti.clientable_type = tappe.tappable_type")
      .where("DATE(tappe.data_tappa) = ?", data)
      .distinct
    }

    def order_by(ordine)
      if ordine == 'fresh'
        unscope(:order).order(Arel.sql('EXTRACT(YEAR FROM data_documento) DESC, created_at DESC'))
      elsif ordine == 'cliente'
        unscope(:order).order(Arel.sql('clientable_type DESC, clientable_id DESC, data_documento DESC, numero_documento DESC'))
      else
        unscope(:order).order(Arel.sql('EXTRACT(YEAR FROM data_documento) DESC, data_documento DESC, numero_documento DESC'))
      end
    end
  end

  class DocumentoFilterProxy < FilterProxy
    def self.query_scope = Documento
    def self.filter_scopes_module = Filters::DocumentoFilterScopes
  end
end