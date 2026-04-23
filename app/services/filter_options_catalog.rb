class FilterOptionsCatalog
  RESOURCES = {
    "libri" => {
      filter_class: Filters::LibroFilter,
      filtering_class: Filters::LibroFilter::Filtering,
      options: ->(filtering) {
        {
          editori: filtering.editori_disponibili,
          categorie: filtering.categorie_disponibili,
          discipline: filtering.discipline_disponibili,
          classi: (1..5).to_a,
          sorted_by: %w[titolo editore categoria]
        }
      }
    },
    "clienti" => {
      filter_class: Filters::ClienteFilter,
      filtering_class: Filters::ClienteFilter::Filtering,
      options: ->(filtering) {
        {
          comuni: filtering.comuni_disponibili,
          tipi: filtering.tipi_disponibili,
          sorted_by: %w[denominazione comune created_at]
        }
      }
    },
    "documenti" => {
      filter_class: Filters::DocumentoFilter,
      filtering_class: Filters::DocumentoFilter::Filtering,
      options: ->(filtering) {
        {
          causali: filtering.causali_disponibili.map { |id, nome| { id: id, nome: nome } },
          tipi_pagamento: Pagamento.where.not(tipo_pagamento: [nil, ""]).distinct.pluck(:tipo_pagamento).sort,
          clientable_types: %w[Scuola Cliente],
          stati_documento: %w[attivi da_consegnare da_pagare completati tutti],
          anni: filtering.anni_disponibili,
          sorted_by: %w[data_documento per_cliente]
        }
      }
    },
    "scuole" => {
      filter_class: Filters::ScuolaFilter,
      filtering_class: Filters::ScuolaFilter::Filtering,
      options: ->(filtering) {
        {
          province: filtering.province_disponibili,
          aree_per_provincia: filtering.aree_per_provincia,
          comuni: filtering.comuni_disponibili,
          tipi_scuola: filtering.tipi_scuola_disponibili,
          appunti_filter: %w[tutte con_appunti],
          adozioni_filter: %w[tutte mie_adozioni adozioni_concorrenza],
          sorted_by: %w[per_direzione solo_scuole denominazione]
        }
      }
    },
    "persone" => {
      filter_class: Filters::PersonaFilter,
      filtering_class: Filters::PersonaFilter::Filtering,
      options: ->(filtering) {
        {
          ruoli: filtering.ruoli_disponibili,
          classi: (1..5).to_a,
          materie: filtering.materie_disponibili,
          stati_contatto: %w[con_email con_telefono con_scuola senza_scuola],
          sorted_by: %w[cognome scuola recenti]
        }
      }
    }
  }.freeze

  def self.available
    RESOURCES.keys
  end

  def self.known?(resource)
    RESOURCES.key?(resource)
  end

  def self.for(resource, user:)
    config = RESOURCES.fetch(resource)
    filter = config[:filter_class].new
    filtering = config[:filtering_class].new(user, filter)
    config[:options].call(filtering)
  end
end
