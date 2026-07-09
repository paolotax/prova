module Filters
  class DocumentoFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def causali_disponibili
      @causali_disponibili ||= Causale.all.order(:causale).pluck(:id, :causale)
    end

    def causali_per_contesto
      @causali_per_contesto ||= Causale.per_contesto
    end

    def show_causali?
      filter.causali.any?
    end

    def tipi_pagamento_disponibili
      ::Documento.tipo_pagamenti.keys
    end

    def show_tipi_pagamento?
      filter.tipi_pagamento.any?
    end

    def clientable_types_disponibili
      {
        "Cliente" => "Cliente",
        "Scuola" => "Scuola",
        "Classe" => "Classe"
      }
    end

    def show_clientable_types?
      filter.clientable_type.present?
    end

    def anni_disponibili
      @anni_disponibili ||= user.documenti.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM data_documento)::integer")).compact.sort.reverse
    end

    def show_anni?
      filter.anno.present?
    end

    def stati_documento_disponibili
      {
        "attivi" => "Attivi",
        "da_consegnare" => "Da consegnare",
        "da_pagare" => "Da pagare",
        "completati" => "Completati",
        "tutti" => "Tutti"
      }
    end

    def show_stato_documento?
      filter.stato_documento.present?
    end

    def filters_active?
      filter.terms.present? ||
      filter.causali.present? ||
      filter.tipi_pagamento.present? ||
      filter.clientable_type.present? ||
      filter.anno.present?
      # stato_documento escluso: ha i suoi tab sopra la tabella
    end

    def controls
      # stato_documento è reso come tab sopra la tabella, non nel pannello.
      %w[ordinamento anni clientable_types causali]
    end

    def cache_key
      [
        "filters/documento_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
