module Filters
  class TappaFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def filtri_disponibili
      {
        "oggi" => "Oggi",
        "domani" => "Domani",
        "settimana" => "Settimana",
        "mese" => "Mese",
        "programmate" => "Programmate",
        "completate" => "Completate",
        "da_programmare" => "Da programmare"
      }
    end

    def show_filtri?
      filter.filter.present?
    end

    def giri_disponibili
      @giri_disponibili ||= user.giri.order(created_at: :desc).pluck(:id, :titolo)
    end

    def show_giri?
      filter.giro_ids.any? || filter.giro_id.present?
    end

    def aree_disponibili
      @aree_disponibili ||= Scuola.where.not(area: [nil, ""]).distinct.pluck(:area).sort
    end

    def show_aree?
      filter.area.present?
    end

    def sort_options
      {
        "" => "Predefinito",
        "per_data" => "Per data",
        "per_data_desc" => "Per data (desc)",
        "per_ordine_e_data" => "Per ordine e data"
      }
    end

    def filters_active?
      filter.used?
    end

    def controls
      %w[filtri giri aree sort]
    end

    def cache_key
      ["filters/tappa_filtering", user.id, filter.params_digest, expanded].join("/")
    end
  end
end
