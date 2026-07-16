module Filters
  # PORO presenter per gestire lo stato UI dei filtri giacenze
  class GiacenzaFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def stati_giacenza_disponibili
      GiacenzaFilter::STATI
    end

    def show_stato_giacenza?
      filter.stato.present?
    end

    def editori_disponibili
      @editori_disponibili ||= user.libri.joins(:editore).distinct.pluck(:editore).compact.sort
    end

    def show_editori?
      filter.editori.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.stato.present? ||
      filter.editori.present?
    end

    def controls
      %w[stato_giacenza editori]
    end

    def cache_key
      [
        "filters/giacenza_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
