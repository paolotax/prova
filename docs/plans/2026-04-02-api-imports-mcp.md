# API Imports per MCP

## Obiettivo

Aggiungere endpoint API per importare libri, clienti e persone via MCP (Scagnozz). L'AI elabora dati, il tool MCP chiama l'API con JSON strutturato, Prova normalizza e importa.

## Endpoint

```
POST /api/v1/libri/imports
POST /api/v1/clienti/imports
POST /api/v1/persone/imports
```

Tutti autenticati via `Api::TokenAuthenticatable`. Account scope via `Current.account`.

## Formato request

### Singolo record

```json
POST /api/v1/libri/imports

{
  "isbn": "9788808199x",
  "titolo": "Tutto Vacanze 3",
  "prezzo": "12.50",
  "editore": "Zanichelli",
  "disciplina": "Vacanze",
  "classe": "3",
  "on_conflict": "update"
}
```

### Batch

```json
POST /api/v1/libri/imports

{
  "libri": [
    { "isbn": "978...", "titolo": "..." },
    { "isbn": "978...", "titolo": "..." }
  ],
  "on_conflict": "skip"
}
```

Il controller distingue singolo/batch dalla presenza della chiave array (`libri`, `clienti`, `persone`).

### Parametro `on_conflict`

- `"update"` (default) — aggiorna il record esistente con i nuovi dati
- `"skip"` — segnala che esiste già, non tocca nulla

## Formato response

Flat, sia per singolo che batch:

```json
{
  "imported": 3,
  "updated": 1,
  "skipped": 2,
  "errors": ["riga 4: ISBN mancante"]
}
```

## Normalizzazione input

### Libri

| Campo fuzzy | Campo rigido | Normalizzazione |
|---|---|---|
| `isbn` | `codice_isbn` | strip, rimuove trattini |
| `prezzo` (stringa "12.50") | `prezzo_cents` (intero 1250) | parse decimale → cents |
| `editore` (nome "Zanichelli") | `editore_id` (uuid) | trova o crea Editore per nome |
| `titolo`, `disciplina`, `classe`, `collana` | idem | strip |

Deduplica su `codice_isbn` nell'account.

### Clienti

| Campo fuzzy | Campo rigido | Normalizzazione |
|---|---|---|
| `nome` | `ragione_sociale` | alias |
| `piva` | `partita_iva` | strip, validazione formato |
| `cf` | `codice_fiscale` | strip, upcase |
| `indirizzo`, `cap`, `citta`, `provincia` | idem | strip |
| `email`, `telefono`, `pec`, `sdi` | idem | strip |

Deduplica su `partita_iva` o `codice_fiscale` nell'account.

### Persone

Stessa logica di `Persone::Importer` esistente. Deduplica su cognome+nome+scuola.

## Routes

```ruby
namespace :api do
  namespace :v1 do
    resources :libri, only: [:index] do
      resources :imports, only: [:create], controller: "api/v1/libri/imports"
    end
    resources :clienti, only: [] do
      resources :imports, only: [:create], controller: "api/v1/clienti/imports"
    end
    resources :persone, only: [:index] do
      resources :imports, only: [:create], controller: "api/v1/persone/imports"
    end
  end
end
```

## Controller pattern

```ruby
module Api
  module V1
    module Libri
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable
        before_action :authenticate_api!

        def create
          if params[:libri].present?
            items = params[:libri].map { |l| l.permit!.to_h }
            result = ::Libri::Importer.import_batch(items, on_conflict: on_conflict)
          else
            importer = ::Libri::Importer.new(**import_params).import
            result = importer.batch_result
          end

          render json: result
        end

        private

        def on_conflict
          params[:on_conflict] || "update"
        end

        def import_params
          params.except(:controller, :action, :libro_id, :libri, :on_conflict)
                .permit!.to_h.symbolize_keys
                .merge(on_conflict: on_conflict)
        end
      end
    end
  end
end
```

Stessa struttura per clienti e persone.

## Importer pattern

```ruby
module Libri
  class Importer
    attr_reader :result

    def initialize(**params)
      @params = params
      @on_conflict = params.delete(:on_conflict) || "update"
    end

    def import
      normalize_params!
      libro = find_existing || build_new

      if libro.persisted? && @on_conflict == "skip"
        @result = { ok: true, skipped: true, id: libro.id }
        @action = :skipped
      else
        libro.assign_attributes(@normalized)
        libro.save!
        @action = libro.previously_new_record? ? :imported : :updated
        @result = { ok: true, id: libro.id, action: @action }
      end

      self
    rescue => e
      @result = { ok: false, error: e.message }
      @action = :error
      self
    end

    def ok? = result[:ok]
    def action = @action

    def batch_result
      {
        imported: @action == :imported ? 1 : 0,
        updated: @action == :updated ? 1 : 0,
        skipped: @action == :skipped ? 1 : 0,
        errors: ok? ? [] : [result[:error]]
      }
    end

    def self.import_batch(items, on_conflict: "update")
      counters = { imported: 0, updated: 0, skipped: 0, errors: [] }
      items.each_with_index do |item, i|
        r = new(**item.symbolize_keys, on_conflict: on_conflict).import
        case r.action
        when :imported then counters[:imported] += 1
        when :updated then counters[:updated] += 1
        when :skipped then counters[:skipped] += 1
        when :error then counters[:errors] << "riga #{i + 1}: #{r.result[:error]}"
        end
      end
      counters
    end

    private

    def normalize_params!
      @normalized = {}
      @normalized[:codice_isbn] = normalize_isbn(@params[:isbn] || @params[:codice_isbn])
      @normalized[:titolo] = @params[:titolo]&.strip
      @normalized[:prezzo_in_cents] = normalize_prezzo(@params[:prezzo] || @params[:prezzo_cents])
      @normalized[:editore_id] = find_or_create_editore(@params[:editore] || @params[:editore_id])
      # ... altri campi
      @normalized.compact!
    end

    def find_existing
      return nil unless @normalized[:codice_isbn]
      Current.account.libri.find_by(codice_isbn: @normalized[:codice_isbn])
    end

    def build_new
      Current.account.libri.new
    end
  end
end
```

## File da creare

- `app/controllers/api/v1/libri/imports_controller.rb`
- `app/controllers/api/v1/clienti/imports_controller.rb`
- `app/controllers/api/v1/persone/imports_controller.rb`
- `app/services/libri/importer.rb`
- `app/services/clienti/importer.rb`

## File da modificare

- `config/routes.rb` — nested import routes, rimuove collection routes persone
- `app/controllers/api/v1/persone_controller.rb` — rimuove `import` e `import_batch`

## MCP Scagnozz

Aggiornare/aggiungere tool MCP:

- `libri_import` → `POST /api/v1/libri/imports`
- `clienti_import` → `POST /api/v1/clienti/imports`
- `persone_import` → `POST /api/v1/persone/imports` (aggiorna endpoint esistente)

## Ordine di implementazione

1. Creare `Libri::Importer` con normalizzazione e deduplica
2. Creare `Clienti::Importer` con normalizzazione e deduplica
3. Creare i 3 imports controller API
4. Aggiornare routes (nuove nested, rimuovi vecchie persone)
5. Migrare `PersoneController#import` al nuovo controller
6. Aggiornare tool MCP Scagnozz
7. Test
