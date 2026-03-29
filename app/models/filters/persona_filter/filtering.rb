module Filters
  class PersonaFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def ruoli_disponibili
      Persona.ruoli.keys
    end

    def show_ruoli?
      filter.ruoli.any?
    end

    def classi_disponibili
      %w[1 2 3 4 5]
    end

    def show_classi?
      filter.classi.any?
    end

    def materie_disponibili
      @materie_disponibili ||= PersonaClasse
        .joins(:persona)
        .where(persone: { account_id: user.accounts.select(:id) })
        .distinct.pluck(:materia).compact.sort
    end

    def show_materie?
      filter.materie.any?
    end

    def stati_contatto_disponibili
      {
        "con_email" => "Con email",
        "con_telefono" => "Con telefono",
        "con_scuola" => "Con scuola",
        "senza_scuola" => "Senza scuola"
      }
    end

    def show_stati_contatto?
      filter.stato_contatto.present?
    end

    def filters_active?
      filter.terms.present? ||
      filter.ruoli.present? ||
      filter.classi.present? ||
      filter.materie.present? ||
      filter.stato_contatto.present?
    end

    def controls
      %w[ruoli classi materie stati_contatto ordinamento]
    end

    def cache_key
      [
        "filters/persona_filtering",
        user.id,
        filter.params_digest,
        expanded
      ].join("/")
    end
  end
end
