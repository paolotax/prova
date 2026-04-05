# API Envelope Complete — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Portare tutti gli endpoint API al formato envelope `{ok, data, count, actions}` su route standard con respond_to, per compatibilità ChatGPT Custom GPT Actions.

**Architecture:** Ogni risorsa usa il proprio Filter esistente per l'index JSON (come fatto per persone/clienti). Le API v1 esistenti (search, stats/adozioni) vengono migrate a controller standard con respond_to. Jbuilder views per la serializzazione. Il CLI scagnozz viene aggiornato di conseguenza.

**Tech Stack:** Rails respond_to, Jbuilder, Filter classes, Minitest

---

### Task 1: Scuole — CRUD JSON + Jbuilder

**Files:**
- Create: `app/views/scuole/_scuola.json.jbuilder`
- Create: `app/views/scuole/show.json.jbuilder`
- Create: `app/views/scuole/index.json.jbuilder`
- Modify: `app/controllers/scuole_controller.rb`
- Create: `test/controllers/scuole_json_test.rb`

**Step 1: Creare jbuilder views**

`_scuola.json.jbuilder`:
```ruby
json.extract! scuola, :id, :denominazione, :codice_ministeriale, :indirizzo, :cap, :comune, :provincia, :regione, :tipo_scuola, :email, :pec, :telefono, :note, :classi_count, :adozioni_count, :created_at, :updated_at
json.url scuola_url(scuola, format: :json)
```

`show.json.jbuilder`:
```ruby
json.partial! "scuole/scuola", scuola: @scuola
```

`index.json.jbuilder`:
```ruby
json.ok true
json.query params[:terms]&.first
json.count @scuole.size
json.data @scuole do |scuola|
  json.partial! "scuole/scuola", scuola: scuola
end
json.actions @scuole.first(3) do |scuola|
  json.name "crea_appunto"
  json.label "Crea appunto per #{scuola.denominazione}"
  json.params do
    json.appuntabile_type "Scuola"
    json.appuntabile_id scuola.id
  end
end
```

**Step 2: Aggiornare ScuoleController**

Aggiungere `skip_before_action :set_user_filtering, if: -> { request.format.json? }` e branch JSON nell'index:

```ruby
def index
  if request.format.json?
    @scuole = @filter.scuole.limit(params[:limit] || 50)
  else
    # existing HTML logic unchanged
  end

  respond_to do |format|
    format.html
    format.turbo_stream
    format.json
    format.xlsx { ... }
  end
end
```

Aggiungere `format.json` a show, create, update, destroy (pattern persone/clienti).

**Step 3: Test**

Creare `test/controllers/scuole_json_test.rb` con: auth, index envelope, search con terms, show, limit. NO create/update/destroy test per ora (scuole sono importate, non create via API di solito).

**Step 4: Commit**

```bash
git commit -m "feat: add JSON API to ScuoleController with envelope format"
```

---

### Task 2: Libri — Envelope index + show JSON

**Files:**
- Modify: `app/views/libri/_libro.json.jbuilder` (aggiornare campi)
- Modify: `app/views/libri/index.json.jbuilder` (envelope)
- Create: `app/views/libri/show.json.jbuilder`
- Modify: `app/controllers/libri_controller.rb`
- Create: `test/controllers/libri_json_test.rb`

**Step 1: Aggiornare jbuilder views**

`_libro.json.jbuilder` — aggiungere campi utili:
```ruby
json.extract! libro, :id, :titolo, :codice_isbn, :classe, :disciplina, :categoria, :note, :created_at, :updated_at
json.prezzo_cents libro.prezzo_cents
json.editore libro.editore&.nome
json.editore_id libro.editore_id
json.url libro_url(libro, format: :json)
```

`index.json.jbuilder` — envelope:
```ruby
json.ok true
json.query params[:terms]&.first
json.count @libri.size
json.data @libri do |libro|
  json.partial! "libri/libro", libro: libro
end
json.actions @libri.first(3) do |libro|
  json.name "crea_ordine"
  json.label "Ordina #{libro.titolo}"
  json.params do
    json.libro_id libro.id
    json.codice_isbn libro.codice_isbn
  end
end
```

`show.json.jbuilder`:
```ruby
json.partial! "libri/libro", libro: @libro
```

**Step 2: Aggiornare LibriController**

L'index ha già `format.json`. Aggiungere:
- `skip_before_action :set_user_filtering, if: -> { request.format.json? }`
- Branch JSON che usa `@filter.libri.limit(params[:limit] || 50)` 
- `format.json` al show

**Step 3: Test + Commit**

---

### Task 3: Search — Migrare a route standard

**Files:**
- Create: `app/controllers/searches_controller.rb` (o usare quello esistente se c'è)
- Create: `app/views/searches/index.json.jbuilder`
- Modify: `config/routes.rb`
- Create: `test/controllers/searches_json_test.rb`

**Step 1: Creare SearchesController**

```ruby
class SearchesController < ApplicationController
  skip_before_action :set_filter, :set_user_filtering, only: [:index], raise: false

  def index
    q = params[:q].to_s.strip
    type_filter = params[:type]
    limit = (params[:limit] || 10).to_i.clamp(1, 20)

    # Riusa la stessa logica di Api::V1::SearchController
    results = []
    # ... search logic across scuole, clienti, classi, persone
    
    respond_to do |format|
      format.json
    end
  end
end
```

Nota: la logica di search è complessa — meglio estrarre in un service o riusare direttamente l'API v1 per ora. Valutare se serve davvero migrare o se basta aggiungere envelope al controller API v1 esistente.

**Alternativa semplice:** aggiornare solo `Api::V1::SearchController` per restituire formato envelope. Non serve migrare la route.

**Step 2: Aggiornare Api::V1::SearchController per envelope**

```ruby
render json: {
  ok: true,
  query: params[:q],
  count: results.size,
  data: results,
  actions: results.first(3).map { |r|
    {
      name: "crea_appunto",
      label: "Crea appunto per #{r[:display] || r[:nome]}",
      params: { appuntabile_type: r[:type].capitalize, appuntabile_id: r[:id] }
    }
  }
}
```

**Step 3: Test + Commit**

---

### Task 4: Stats Adozioni — Envelope format

**Files:**
- Modify: `app/controllers/api/v1/stats/adozioni_controller.rb`
- Create: `test/controllers/api/v1/stats/adozioni_json_test.rb`

**Step 1: Aggiornare il render per envelope**

Il controller attuale fa `render json: query.call`. Wrappare in envelope:

```ruby
result = query.call
render json: {
  ok: true,
  query: params.slice(:provincia, :editore, :disciplina, :titolo, :classe, :scuola).compact_blank,
  count: result.is_a?(Array) ? result.size : result[:data]&.size,
  data: result.is_a?(Array) ? result : result[:data],
  actions: []
}
```

Nota: verificare la struttura attuale di `query.call` prima di wrappare.

**Step 2: Test + Commit**

---

### Task 5: Appunti — Index/show JSON con envelope

**Files:**
- Modify: `app/views/appunti/_appunto.json.jbuilder`
- Modify: `app/views/appunti/index.json.jbuilder`
- Modify: `app/controllers/appunti_controller.rb`
- Create: `test/controllers/appunti_json_test.rb`

**Step 1: Aggiornare jbuilder**

`_appunto.json.jbuilder` — arricchire:
```ruby
json.extract! appunto, :id, :nome, :appunto, :appuntabile_type, :appuntabile_id, :created_at, :updated_at
json.appuntabile_display appunto.appuntabile&.to_s
json.url appunto_url(appunto, format: :json)
```

`index.json.jbuilder` — envelope:
```ruby
json.ok true
json.count @appunti.size
json.data @appunti do |appunto|
  json.partial! "appunti/appunto", appunto: appunto
end
json.actions []
```

**Step 2: Aggiornare controller + Test + Commit**

---

### Task 6: Scagnozz CLI — Aggiornare tutti i comandi

**Files:**
- Modify: `scagnozz-cli/internal/commands/` — aggiornare endpoint e parsing per scuole, libri, search
- Modify: `scagnozz-cli/internal/mcp/tools.go` — aggiornare endpoint e aggiungere tool scuole

**Step 1: Aggiungere scuole CRUD al CLI e MCP**

Pattern identico a persone: list, show + tool MCP.

**Step 2: Aggiornare libri search per envelope**

**Step 3: Aggiornare search per envelope**

**Step 4: Aggiornare stats per envelope**

**Step 5: Build + release**

```bash
cd scagnozz-cli && bash scripts/release.sh
```

---

### Task 7: OpenAPI Schema per ChatGPT

**Files:**
- Create: `docs/openapi.yaml`

**Step 1: Generare schema OpenAPI**

Creare un file OpenAPI 3.0 con tutti gli endpoint:
- GET /persone.json — list con filtri
- GET /persone/{id}.json — show
- POST /persone.json — create
- PATCH /persone/{id}.json — update
- DELETE /persone/{id}.json — delete
- (stessa struttura per clienti, scuole, libri)
- GET /api/v1/search — search
- GET /api/v1/stats/adozioni — stats
- POST /api/v1/appunti — create appunto

Questo file si carica nel GPT Builder come Action schema.

**Step 2: Commit**
