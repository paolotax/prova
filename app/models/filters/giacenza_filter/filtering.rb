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
      filter.stati.any?
    end

    def editori_disponibili
      @editori_disponibili ||= user.libri.joins(:editore).distinct.pluck(:editore).compact.sort
    end

    def show_editori?
      filter.editori.any?
    end

    def categorie_disponibili
      @categorie_disponibili ||= (filter.account || Current.account).libri
        .joins(:categoria).distinct.pluck(:nome_categoria).compact.sort
    end

    def show_categorie?
      filter.categorie.any?
    end

    def anni_disponibili
      @anni_disponibili ||= (filter.account || Current.account).documenti
        .distinct.pluck(Arel.sql("EXTRACT(YEAR FROM data_documento)::integer")).compact.sort.reverse
    end

    def show_anni?
      filter.anno != Date.current.year
    end

    def filters_active?
      filter.terms.present? ||
      filter.stati.present? ||
      filter.editori.present? ||
      filter.categorie.present? ||
      filter.anno != Date.current.year
    end

    def controls
      %w[stato_giacenza anni editori categorie]
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
