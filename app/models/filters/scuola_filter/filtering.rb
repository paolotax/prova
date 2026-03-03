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

    def province_disponibili
      @province_disponibili ||= Current.scuole.distinct.pluck(:provincia).compact.sort
    end

    def aree_per_provincia
      @aree_per_provincia ||= Current.scuole
        .where.not(area: [nil, ""])
        .where.not("area LIKE '\\_\\_%'")  # escludi aree interne (__da_pulire__ etc)
        .distinct.pluck(:provincia, :area)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last).sort }
    end

    def show_province?
      filter.province.any? || filter.aree.any?
    end

    def comuni_disponibili
      @comuni_disponibili ||= begin
        scope = Current.scuole
        scope = scope.where(provincia: filter.province) if filter.province.present?
        scope.distinct.pluck(:comune).compact.sort
      end
    end

    def show_comuni?
      filter.comuni.any?
    end

    def provincia_per_comune
      @provincia_per_comune ||= Current.scuole
        .where.not(comune: nil, provincia: nil)
        .distinct.pluck(:comune, :provincia)
        .to_h
    end

    def tipi_scuola_disponibili
      @tipi_scuola_disponibili ||= Current.scuole.distinct.pluck(:tipo_scuola).compact.sort
    end

    def show_tipi_scuola?
      filter.tipi_scuola.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.province.present? ||
      filter.aree.present? ||
      filter.comuni.present? ||
      filter.tipi_scuola.present? ||
      filter.con_appunti? ||
      filter.con_mie_adozioni? ||
      filter.con_adozioni_concorrenza?
    end

    def controls
      %w[ordinamento tipi_scuola province comuni con_appunti con_adozioni_mie]
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
