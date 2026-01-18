module Filters
  class Documento::Filtering
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

    def show_causali?
      causali_disponibili.any?
    end

    def statuses_disponibili
      ::Documento.statuses.keys
    end

    def show_statuses?
      statuses_disponibili.any?
    end

    def tipi_pagamento_disponibili
      ::Documento.tipo_pagamenti.keys
    end

    def show_tipi_pagamento?
      tipi_pagamento_disponibili.any?
    end

    def clientable_types_disponibili
      {
        "Cliente" => "Cliente",
        "ImportScuola" => "Scuola"
      }
    end

    def show_clientable_types?
      clientable_types_disponibili.any?
    end

    def anni_disponibili
      @anni_disponibili ||= user.documenti.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM data_documento)::integer")).compact.sort.reverse
    end

    def show_anni?
      anni_disponibili.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.causali.present? ||
      filter.statuses.present? ||
      filter.tipi_pagamento.present? ||
      filter.clientable_type.present? ||
      filter.anno.present? ||
      filter.consegnati.present? ||
      filter.pagati.present?
    end

    def controls
      %w[anni clientable_types causali statuses tipi_pagamento]
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
