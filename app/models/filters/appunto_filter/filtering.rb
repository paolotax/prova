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

    def statuses_disponibili
      ::Appunto::STATO_APPUNTI
    end

    def states_disponibili
      ::Appunto::FIZZY_STATES
    end

    def show_statuses?
      false
    end

    def show_states?
      false
    end

    def filters_active?
      filter.terms.present? || filter.statuses.present? || filter.state.present?
    end

    def controls
      %w[states]
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
