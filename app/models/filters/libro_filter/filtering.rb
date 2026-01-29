module Filters
  # PORO presenter per gestire lo stato UI dei filtri libri
  class LibroFilter::Filtering
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
      filter.editori.any?
    end

    def categorie_disponibili
      @categorie_disponibili ||= user.libri.joins(:categoria).distinct.pluck(:nome_categoria).compact.sort
    end

    def show_categorie?
      filter.categorie.any?
    end

    def discipline_disponibili
      @discipline_disponibili ||= user.libri.distinct.pluck(:disciplina).compact.sort
    end

    def show_discipline?
      filter.discipline.any?
    end

    def classi_disponibili
      @classi_disponibili ||= user.libri.distinct.pluck(:classe).compact.sort
    end

    def show_classi?
      filter.classi.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.editori.present? ||
      filter.categorie.present? ||
      filter.discipline.present? ||
      filter.classi.present?
    end

    def controls
      %w[editori categorie discipline classi]
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
