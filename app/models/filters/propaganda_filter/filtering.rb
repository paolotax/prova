module Filters
  class PropagandaFilter::Filtering
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
        .where.not("area LIKE '\\_\\_%'")
        .distinct.pluck(:provincia, :area)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map(&:last).sort }
    end

    def show_province?
      filter.province.any? || filter.aree.any?
    end

    def giri_disponibili
      @giri_disponibili ||= user.giri.order(created_at: :desc)
    end

    def show_giri?
      filter.giro_ids.any?
    end

    def filters_active?
      filter.terms.present? ||
      filter.province.present? ||
      filter.aree.present? ||
      filter.giro_ids.present?
    end

    def controls
      %w[province giri]
    end

    def cache_key
      [
        "filters/propaganda_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
