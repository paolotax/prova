module Filters
  class ClienteFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def comuni_disponibili
      @comuni_disponibili ||= user.clienti.distinct.pluck(:comune).compact.sort
    end

    def show_comuni?
      filter.comuni.any?
    end

    def tipi_disponibili
      @tipi_disponibili ||= user.clienti.distinct.pluck(:tipo_cliente).compact.sort
    end

    def show_tipi?
      filter.tipi.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.comuni.present? ||
      filter.tipi.present? ||
      filter.fornitori.present?
    end

    def controls
      %w[comuni tipi fornitori]
    end

    def cache_key
      [
        "filters/cliente_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
