# Sistema Filtri - Guida di Riferimento

Documentazione del sistema filtri implementato in Prova, basato sui pattern di Fizzy.

## Architettura

Il sistema filtri è composto da 4 componenti principali:

```
Filters::*Filter           # Modello STI per persistenza e logica filtro
Filters::*Filter::Fields   # Definizione campi e parametri
Filters::*Filter::Filtering # Presenter per stato UI
Filters::*Filter::Summarized # Generazione summary testuale
```

## Struttura File

```
app/models/filters/
├── base.rb                    # Classe base STI
├── appunto_filter.rb
├── appunto_filter/
│   ├── fields.rb
│   ├── filtering.rb
│   └── summarized.rb
├── libro_filter.rb
├── libro_filter/
│   └── ...
├── scuola_filter.rb
├── scuola_filter/
│   └── ...
├── cliente_filter.rb
├── cliente_filter/
│   └── ...
├── documento_filter.rb
├── documento_filter/
│   └── ...
├── entry_filter.rb
└── entry_filter/
    └── ...
```

## Convenzione Nomi

| Componente | Pattern | Esempio |
|------------|---------|---------|
| Modello filtro | `Filters::*Filter` | `Filters::LibroFilter` |
| Fields module | `Filters::*Filter::Fields` | `Filters::LibroFilter::Fields` |
| Filtering presenter | `Filters::*Filter::Filtering` | `Filters::LibroFilter::Filtering` |
| Associazione User | `*_filter_filters` | `libro_filter_filters` |
| filter_type (view) | `*_filter` | `libro_filter` |

## Componenti

### 1. Filter (Modello STI)

```ruby
# app/models/filters/libro_filter.rb
module Filters
  class LibroFilter < Base
    include LibroFilter::Fields
    include LibroFilter::Summarized

    def libri(base_scope = nil)
      base_scope ||= (account || Current.account).libri
      result = base_scope

      # Applica filtri
      result = result.where(...) if terms.present?
      result = result.where(editore: editori) if editori.present?
      # ...

      result.distinct
    end

    alias_method :results, :libri
  end
end
```

### 2. Fields Module

Definisce i campi del filtro e i parametri permessi:

```ruby
# app/models/filters/libro_filter/fields.rb
module Filters
  class LibroFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :sorted_by,
        editori: [],
        categorie: [],
        terms: []
      ].freeze

      class_methods do
        def default_values
          { sorted_by: "titolo" }
        end
      end

      included do
        store_accessor :fields, :sorted_by, :terms, :editori, :categorie

        def terms
          Array(super)
        end

        def terms=(value)
          super(Array(value).filter(&:present?))
        end

        # ... altri accessors
      end

      def as_params
        @as_params ||= {}.tap do |params|
          params[:terms] = terms
          params[:editori] = editori
          # ...
        end.compact_blank
      end
    end
  end
end
```

### 3. Filtering Presenter (Strategia Fizzy)

Controlla lo stato UI dei filtri. Usa la **strategia Fizzy**: i filtri appaiono solo quando l'utente ha selezionato qualcosa.

```ruby
# app/models/filters/libro_filter/filtering.rb
module Filters
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

    # Dati disponibili per i dropdown
    def editori_disponibili
      @editori_disponibili ||= user.libri.joins(:editore).distinct.pluck(:editore).compact.sort
    end

    # STRATEGIA FIZZY: mostra solo se l'utente ha selezionato qualcosa
    def show_editori?
      filter.editori.any?
    end

    def show_categorie?
      filter.categorie.any?
    end

    def filters_active?
      filter.terms.present? || filter.editori.present? || filter.categorie.present?
    end

    # Quali controlli renderizzare
    def controls
      %w[editori categorie discipline classi]
    end
  end
end
```

### 4. Summarized Module

Genera un riassunto testuale del filtro attivo:

```ruby
# app/models/filters/libro_filter/summarized.rb
module Filters
  class LibroFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, editori_summary, categorie_summary].compact
        parts.any? ? parts.to_sentence : "Tutti i libri"
      end

      private

      def terms_summary
        "\"#{terms.join(', ')}\"" if terms.any?
      end

      def editori_summary
        editori.count == 1 ? editori.first : "#{editori.count} editori" if editori.any?
      end
    end
  end
end
```

## Controller Setup

```ruby
# app/controllers/libri_controller.rb
class LibriController < ApplicationController
  include FilterScoped

  FILTER_PARAMS = Filters::LibroFilter::Fields::PERMITTED_PARAMS

  def index
    @libri = @filter.libri
    set_page_and_extract_portion_from @libri
  end
end
```

Il concern `FilterScoped` gestisce automaticamente:
- `@filter` - istanza del filtro
- `@user_filtering` - presenter per la UI

```ruby
# app/controllers/concerns/filter_scoped.rb
module FilterScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_filter, only: [:index]
    before_action :set_user_filtering, only: [:index]
  end

  private

  def filter_class
    "Filters::#{controller_name.classify.singularize}Filter".constantize
  end

  def filtering_class
    "Filters::#{controller_name.classify.singularize}Filter::Filtering".constantize
  end
end
```

## View Setup

```erb
<%# app/views/libri/index.html.erb %>
<%= render "filters/settings",
    filter_url: libri_path,
    filter_type: "libro_filter",
    user_filtering: @user_filtering,
    no_filtering_url: libri_path %>

<%= turbo_frame_tag :search_results do %>
  <%# contenuto filtrato %>
<% end %>
```

## User Associations

```ruby
# app/models/user/available_filters.rb
module User::AvailableFilters
  extend ActiveSupport::Concern

  included do
    has_many :filters, class_name: "Filters::Base", foreign_key: :creator_id
    has_many :libro_filter_filters, class_name: "Filters::LibroFilter", foreign_key: :creator_id
    has_many :scuola_filter_filters, class_name: "Filters::ScuolaFilter", foreign_key: :creator_id
    has_many :cliente_filter_filters, class_name: "Filters::ClienteFilter", foreign_key: :creator_id
    has_many :documento_filter_filters, class_name: "Filters::DocumentoFilter", foreign_key: :creator_id
    has_many :appunto_filter_filters, class_name: "Filters::AppuntoFilter", foreign_key: :creator_id
    has_many :entry_filter_filters, class_name: "Filters::EntryFilter", foreign_key: :creator_id
  end
end
```

## Strategia Visibilità Filtri (Fizzy)

I metodi `show_*?` controllano quando mostrare i chip dei filtri:

| Strategia | Codice | Quando appare |
|-----------|--------|---------------|
| **Fizzy (usata)** | `filter.editori.any?` | Solo se l'utente ha selezionato |
| Dati esistenti | `editori_disponibili.any?` | Se esistono opzioni nel DB |
| Sempre nascosto | `false` | Solo espandendo i filtri |

La strategia Fizzy mantiene l'interfaccia pulita: i chip appaiono solo quando servono.

## Partial Filtri

I controlli dei filtri sono in `app/views/filters/settings/`:

```
_controls.html.erb      # Itera su user_filtering.controls
_terms.html.erb         # Campo ricerca testuale
_editori.html.erb       # Dropdown editori
_categorie.html.erb     # Dropdown categorie
_entryable_types.html.erb # Dropdown tipo entry
_states.html.erb        # Dropdown stato
...
```

Ogni partial usa `data-filter-show` per la visibilità:

```erb
<%= tag.div class: "quick-filter",
    data: {
      filter_show: user_filtering.show_editori?,
      ...
    } do %>
```

## Creare un Nuovo Filtro

1. **Creare i file** in `app/models/filters/nuovo_filter/`:
   - `fields.rb` - campi e PERMITTED_PARAMS
   - `filtering.rb` - presenter UI con metodi show_*
   - `summarized.rb` - generazione summary

2. **Creare il modello** `app/models/filters/nuovo_filter.rb`

3. **Aggiungere associazione** in `user/available_filters.rb`:
   ```ruby
   has_many :nuovo_filter_filters, class_name: "Filters::NuovoFilter", foreign_key: :creator_id
   ```

4. **Aggiungere al controller**:
   ```ruby
   include FilterScoped
   FILTER_PARAMS = Filters::NuovoFilter::Fields::PERMITTED_PARAMS
   ```

5. **Aggiungere alla view**:
   ```erb
   <%= render "filters/settings", filter_type: "nuovo_filter", ... %>
   ```

6. **Creare partial controlli** se necessario in `app/views/filters/settings/`
