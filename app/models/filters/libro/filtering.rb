module Filters
  # PORO presenter per gestire lo stato UI dei filtri scuole
  class Libro::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def editori_disponibili
      @editori_disponibili ||= user.libri.joins(:editore).distinct.pluck(:editore).compact.sort
    end

    def show_editori?
      editori_disponibili.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.editori.present? ||
      filter.categorie.present?
    end

    def cache_key
      [
        "filters/libro_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
