module Filters
  module DocumentoFilterScopes
    extend FilterScopeable

    filter_scope :search, ->(search) {
      # joins("LEFT JOIN import_scuole ON documenti.clientable_id = import_scuole.id AND documenti.clientable_type = 'ImportScuola'")
      # .joins("LEFT JOIN clienti ON documenti.clientable_id = clienti.id AND documenti.clientable_type = 'Cliente'")
      joins("JOIN causali ON documenti.causale_id = causali.id")
      .where('import_scuole."DENOMINAZIONESCUOLA" ILIKE ?
              OR import_scuole."DESCRIZIONECOMUNE" ILIKE ?
              OR import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO" ILIKE ?
              OR clienti.denominazione ILIKE ?
              OR clienti.comune ILIKE ?
              OR causali.causale ILIKE ?',
      "%#{search}%", "%#{search}%","%#{search}%", "%#{search}%", "%#{search}%", "%#{search}%")
    }

    filter_scope :search_libro, ->(search) { joins(documento_righe: [riga: :libro]).where("libri.titolo ILIKE ?", "%#{search}%").distinct }
    filter_scope :causale, ->(causale) { joins(:causale).where("causali.causale ILIKE ?", "%#{causale}%") }
    filter_scope :status, ->(status) { where(status: status) }
    filter_scope :tipo_pagamento, ->(tipo_pagamento) { where(tipo_pagamento: tipo_pagamento) }

    filter_scope :ordina_per, ->(ordine) { order_by(ordine) }

    filter_scope :anno, ->(anno) { where('EXTRACT(YEAR FROM data_documento) = ?', anno) }

    filter_scope :consegnato_il, ->(data) { where('DATE(consegnato_il) = ?', data.to_date) }
    filter_scope :pagato_il, ->(data) { where('DATE(pagato_il) = ?', data.to_date) }

    filter_scope :nel_baule_del_giorno, ->(data) {
      sanitized_date = ActiveRecord::Base.connection.quote(data)

      union_sql = <<-SQL
        (
          SELECT DISTINCT documenti.*
          FROM documenti
          INNER JOIN tappe ON documenti.clientable_id = tappe.tappable_id
            AND documenti.clientable_type = tappe.tappable_type
          WHERE DATE(tappe.data_tappa) = #{sanitized_date}
            AND ((documenti.consegnato_il IS NULL) OR (documenti.pagato_il IS NULL))
        )
        UNION
        (
          SELECT DISTINCT documenti.*
          FROM documenti
          INNER JOIN tappe ON documenti.clientable_id = tappe.tappable_id
            AND documenti.clientable_type = tappe.tappable_type
          WHERE (DATE(documenti.consegnato_il) = #{sanitized_date} OR DATE(documenti.pagato_il) = #{sanitized_date})
            AND documenti.status in (2, 3, 4, 5)
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