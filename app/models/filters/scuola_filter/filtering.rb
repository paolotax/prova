module Filters
  # PORO presenter per gestire lo stato UI dei filtri scuole
  class ScuolaFilter::Filtering
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
      @comuni_disponibili ||= user.accounts.first.scuole.distinct.pluck(:comune).compact.sort
    end

    def show_comuni?
      filter.comuni.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.comuni.present? ||
      filter.con_appunti? ||
      filter.con_mie_adozioni? ||
      filter.con_adozioni_concorrenza?
    end

    def controls
      %w[comuni con_appunti con_adozioni_mie]
    end

    def cache_key
      [
        "filters/scuola_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
