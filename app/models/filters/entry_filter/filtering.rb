module Filters
  # PORO presenter per gestire lo stato UI dei filtri entry
  class EntryFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def entryable_types_disponibili
      {
        "" => "Tutti i tipi",
        "Documento" => "Documenti",
        "Appunto" => "Appunti"
      }
    end

    def states_disponibili
      {
        "" => "Tutti gli stati",
        "active" => "Attivi",
        "closed" => "Chiusi",
        "postponed" => "Rimandati"
      }
    end

    def show_entryable_types?
      filter.entryable_type.present?
    end

    def show_states?
      filter.state.present?
    end

    def show_golden?
      filter.golden == "true"
    end

    def filters_active?
      filter.terms.present? ||
        filter.entryable_type.present? ||
        filter.state.present? ||
        filter.golden == "true"
    end

    def controls
      %w[entryable_types states]
    end

    def cache_key
      [
        "filters/entry_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
