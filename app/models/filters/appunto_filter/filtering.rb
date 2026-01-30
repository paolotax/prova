module Filters
  # PORO presenter per gestire lo stato UI dei filtri appunti
  class AppuntoFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def anni_disponibili
      @anni_disponibili ||= user.appunti
        .distinct
        .pluck(Arel.sql("EXTRACT(YEAR FROM created_at)::integer"))
        .compact
        .sort
        .reverse
    end

    def show_anni?
      filter.anno.present?
    end

    def states_disponibili
      ::Appunto::FIZZY_STATES
    end

    def show_states?
      filter.state.present?
    end

    def filters_active?
      filter.terms.present? || filter.anno.present? || filter.state.present?
    end

    def controls
      %w[anni states]
    end

    def cache_key
      [
        "filters/appunto_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
