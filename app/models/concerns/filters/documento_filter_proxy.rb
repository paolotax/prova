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

    filter_scope :ordina_per, ->(ordine) { order_by(ordine) }#{ ordine == "fresh"? order(updated_at: :desc) : order(data_documento: :desc, numero_documento: :desc ) }

    
    def order_by(ordine)
      if ordine == 'fresh'
        unscope(:order).order(created_at: :desc)
      else
        unscope(:order).order(data_documento: :desc, numero_documento: :desc )
      end
    end
  end

  class DocumentoFilterProxy < FilterProxy
    def self.query_scope = Documento
    def self.filter_scopes_module = Filters::DocumentoFilterScopes
  end
end