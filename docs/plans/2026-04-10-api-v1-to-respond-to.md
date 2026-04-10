# API v1 → respond_to JSON (pattern Fizzy)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminare i controller API v1 e far passare tutto il JSON dai controller web con `respond_to`, come Fizzy.

**Architecture:** I controller web servono sia HTML che JSON. Il CLI Go chiama le stesse route con `Accept: application/json` e Bearer token. Gli endpoint speciali (me, search, stats, imports) restano sotto `/api/` senza il namespace `v1/`. Il MCP server resta invariato (chiama i modelli direttamente).

**Tech Stack:** Rails 8.1, Jbuilder, Bearer token auth (già in PasswordlessAuthentication)

---

## Stato attuale

I controller web già supportano `respond_to` JSON per quasi tutto:
- Appunti, Documenti, Tappe, Giri, Clienti, Persone — CRUD completo con JSON ✅
- Scuole — index, show, update con JSON ✅ (create/destroy non serve per ora)
- Libri — index, show con JSON ✅ — **manca create, update, destroy**

Endpoint speciali oggi sotto `/api/v1/`:
- `GET /api/v1/me` → profilo utente
- `GET /api/v1/search` → ricerca unificata
- `POST /api/v1/libri/imports`, `POST /api/v1/persone/imports`, `POST /api/v1/clienti/imports` → batch import (3 controller quasi identici)
- `GET /api/v1/stats/adozioni` → dati MIUR
- `POST /api/whatsapp/contacts` → webhook (resta invariato)

Le jbuilder views esistono per tutte le risorse.

## Cosa cambia

1. Libri: aggiungere JSON a create, update, destroy
2. Search: aggiungere `format.json` al SearchController web
3. Imports: unificare i 3 controller in ImportsController con `format.json`
4. Route: spostare me, search, stats da `/api/v1/` a `/api/`
5. Eliminare i controller API v1 e le relative route

## Cosa NON cambia

- MCP server (`/api/mcp`) — resta invariato
- MCP tools — chiamano i modelli direttamente, non passano dai controller
- WhatsApp webhook (`/api/whatsapp/contacts`) — resta invariato
- Scuole create/destroy — non servono per ora
- Tutte le views HTML/turbo_stream — non si toccano

---

### Task 1: Libri — aggiungere JSON a create, update, destroy

**Files:**
- Modify: `app/controllers/libri_controller.rb`
- Test: `test/controllers/libri_controller_test.rb`

**Step 1: Write failing tests**

```ruby
# test/controllers/libri_controller_test.rb

class LibriControllerJsonTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @token = access_tokens(:one).token
    @libro = libri(:one)
    @editore = editori(:one)
    @categoria = categorie(:one)
  end

  test "create libro via JSON" do
    post libri_url(account_id: @account.id, format: :json),
      params: { libro: { titolo: "Nuovo libro test", codice_isbn: "9781234567890", prezzo: "12.50", editore_id: @editore.id, categoria_id: @categoria.id } },
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Nuovo libro test", json["titolo"]
  end

  test "update libro via JSON" do
    patch libro_url(@libro, account_id: @account.id, format: :json),
      params: { libro: { titolo: "Titolo aggiornato" } },
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :ok
    json = JSON.parse(response.body)
    assert_equal "Titolo aggiornato", json["titolo"]
  end

  test "destroy libro via JSON" do
    delete libro_url(@libro, account_id: @account.id, format: :json),
      headers: { "Authorization" => "Bearer #{@token}" }

    assert_response :no_content
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `docker exec prova-app-1 bin/rails test test/controllers/libri_controller_test.rb`

**Step 3: Implement — modify LibriController**

Il `create` attuale fa redirect a `new_libro_path` (crea un draft). Per JSON serve un create diretto:

```ruby
# app/controllers/libri_controller.rb

def create
  respond_to do |format|
    format.html { redirect_to new_libro_path }
    format.json do
      @libro = Current.account.libri.build(libro_params)
      @libro.user = Current.user
      if @libro.save
        render :show, status: :created, location: @libro
      else
        render json: @libro.errors, status: :unprocessable_entity
      end
    end
  end
end

def update
  if @libro.update(libro_params)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to libro_path(@libro), notice: "Libro modificato!" }
      format.json { render :show, status: :ok, location: @libro }
    end
  else
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
      format.json { render json: @libro.errors, status: :unprocessable_entity }
    end
  end
end

def destroy
  @libro.destroy!

  respond_to do |format|
    format.turbo_stream do
      flash.now[:notice] = "Libro eliminato."
      render turbo_stream: turbo_stream.remove(@libro)
    end
    format.html { redirect_to libri_url, notice: "Libro eliminato.", status: :see_other }
    format.json { head :no_content }
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `docker exec prova-app-1 bin/rails test test/controllers/libri_controller_test.rb`

**Step 5: Commit**

```bash
git add app/controllers/libri_controller.rb test/controllers/libri_controller_test.rb
git commit -m "feat: add JSON respond_to for libri create, update, destroy"
```

---

### Task 2: Search — aggiungere format.json

**Files:**
- Modify: `app/controllers/search_controller.rb`
- Create: `app/views/search/show.json.jbuilder`
- Test: `test/controllers/search_controller_test.rb`

**Step 1: Write failing test**

```ruby
test "search via JSON returns results" do
  get search_url(account_id: @account.id, q: "test", format: :json),
    headers: { "Authorization" => "Bearer #{@token}" }

  assert_response :success
  json = JSON.parse(response.body)
  assert json.key?("results")
end
```

**Step 2: Run test to verify it fails**

**Step 3: Implement**

```ruby
# app/controllers/search_controller.rb — aggiungere format.json al respond_to

def show
  return head(:no_content) if params[:q].blank? || params[:q].length < 2

  @results = SEARCHABLES.filter_map do |key, config|
    records = Current.account.public_send(key)
                .public_send(config[:search], params[:q])
                .limit(params[:limit] || 6)
    next if records.empty?

    { key:, records:, **config }
  end

  respond_to do |format|
    format.html
    format.json
  end
end
```

```ruby
# app/views/search/show.json.jbuilder
json.query params[:q]
json.count @results.sum { |r| r[:records].size }
json.results @results do |group|
  json.type group[:key]
  json.label group[:label]
  json.items group[:records] do |record|
    json.id record.id
    json.type group[:key].to_s.singularize.capitalize
    json.display record.to_combobox_display
    json.appuntabile_value "#{group[:key].to_s.singularize.capitalize}:#{record.id}"
  end
end
```

**Step 4: Run tests**

**Step 5: Commit**

```bash
git add app/controllers/search_controller.rb app/views/search/show.json.jbuilder test/controllers/search_controller_test.rb
git commit -m "feat: add JSON format to SearchController"
```

---

### Task 3: Imports — unificare in ImportsController con format.json

**Files:**
- Modify: `app/controllers/imports_controller.rb`
- Test: `test/controllers/imports_controller_test.rb`

**Step 1: Write failing tests**

```ruby
test "import persone via JSON" do
  post imports_url(account_id: @account.id, format: :json),
    params: { type: "persone", items: [{ cognome: "Rossi", nome: "Maria", scuola: "test" }] },
    headers: { "Authorization" => "Bearer #{@token}" },
    as: :json

  assert_response :success
  json = JSON.parse(response.body)
  assert json.key?("results")
end

test "import libri via JSON" do
  post imports_url(account_id: @account.id, format: :json),
    params: { type: "libri", items: [{ isbn: "9781234567890", titolo: "Test", prezzo: "10.00" }] },
    headers: { "Authorization" => "Bearer #{@token}" },
    as: :json

  assert_response :success
end

test "import clienti via JSON" do
  post imports_url(account_id: @account.id, format: :json),
    params: { type: "clienti", items: [{ nome: "Test SRL", piva: "12345678901" }] },
    headers: { "Authorization" => "Bearer #{@token}" },
    as: :json

  assert_response :success
end
```

**Step 2: Run tests to verify they fail**

**Step 3: Implement**

```ruby
# app/controllers/imports_controller.rb

def create
  respond_to do |format|
    format.html do
      @import = Current.user.import_records.new(import_params)
      @import.account = current_account
      if @import.save
        ImportProcessJob.perform_later(@import.id)
        redirect_to import_path(@import)
      else
        @import_type = @import.import_type || "libri"
        @import_subtype = params.dig(:import_record, :metadata, :subtype)
        render :new, status: :unprocessable_entity
      end
    end
    format.json do
      result = import_from_json
      render json: result
    end
  end
end

private

IMPORTERS = {
  "persone" => ::Persone::Importer,
  "libri"   => ::Libri::Importer,
  "clienti" => ::Clienti::Importer
}.freeze

def import_from_json
  type = params[:type]
  importer_class = IMPORTERS[type]
  return { ok: false, error: "Tipo non valido: #{type}" } unless importer_class

  items = params[:items]&.map { |i| i.permit!.to_h } || []
  on_conflict = params[:on_conflict] || "update"

  if items.any?
    importer_class.import_batch(items, on_conflict: on_conflict)
  else
    # Singolo: tutti i params tranne quelli di routing
    single_params = params.except(:controller, :action, :format, :type, :items, :on_conflict, :import).permit!.to_h.symbolize_keys
    importer = importer_class.new(**single_params.merge(on_conflict: on_conflict)).import
    importer.batch_result
  end
end
```

**Step 4: Run tests**

**Step 5: Commit**

```bash
git add app/controllers/imports_controller.rb test/controllers/imports_controller_test.rb
git commit -m "feat: add JSON sync import to ImportsController (replaces 3 API v1 import controllers)"
```

---

### Task 4: Route — riorganizzare /api/

**Files:**
- Modify: `config/routes.rb`

**Step 1: Write failing tests**

Verificare che le nuove route funzionino e le vecchie no.

```ruby
test "GET /api/me works" do
  get "/api/me", headers: { "Authorization" => "Bearer #{@token}" }
  assert_response :success
end

test "GET /api/search works" do
  get "/api/search?q=test", headers: { "Authorization" => "Bearer #{@token}" }
  assert_response :success
end

test "GET /api/stats/adozioni works" do
  get "/api/stats/adozioni?group_by=editore&provincia=TO",
    headers: { "Authorization" => "Bearer #{@token}" }
  assert_response :success
end
```

**Step 2: Implement le nuove route**

```ruby
# config/routes.rb — sezione API

post "api/mcp", to: "mcp#handle"

namespace :api do
  post 'whatsapp/contacts', to: 'whatsapp#create'

  # Endpoint speciali (non CRUD, non legati a una risorsa account-scoped)
  resource :me, only: [:show], controller: 'me'
  resources :search, only: [:index]
  namespace :stats do
    get :adozioni, to: 'adozioni#index'
  end
end
```

Spostare i controller da `Api::V1::MeController` → `Api::MeController` (eliminando il namespace V1).

**Step 3: Creare i controller senza V1**

```ruby
# app/controllers/api/me_controller.rb
module Api
  class MeController < ActionController::API
    include Api::TokenAuthenticatable
    before_action :authenticate_api!

    def show
      render json: {
        email: Current.user.email,
        name: Current.user.name,
        account: Current.account.name,
        account_id: Current.account.id
      }
    end
  end
end
```

```ruby
# app/controllers/api/search_controller.rb
module Api
  class SearchController < ActionController::API
    include Api::TokenAuthenticatable
    before_action :authenticate_api!

    # Stessa logica di Api::V1::SearchController, copiata identica
  end
end
```

```ruby
# app/controllers/api/stats/adozioni_controller.rb
module Api
  module Stats
    class AdozioniController < ActionController::API
      include Api::TokenAuthenticatable
      before_action :authenticate_api!

      # Stessa logica di Api::V1::Stats::AdozioniController, copiata identica
    end
  end
end
```

**Step 4: Run tests**

**Step 5: Commit**

```bash
git add config/routes.rb app/controllers/api/me_controller.rb app/controllers/api/search_controller.rb app/controllers/api/stats/adozioni_controller.rb
git commit -m "feat: move API endpoints from /api/v1/ to /api/"
```

---

### Task 5: Rimuovere API v1

**Files:**
- Delete: `app/controllers/api/v1/` (tutta la directory)
- Modify: `config/routes.rb` (rimuovere il namespace v1)

**Step 1: Verificare che nessun test usi le vecchie route**

```bash
docker exec prova-app-1 grep -r "api/v1" test/
```

Aggiornare eventuali test che puntano a `/api/v1/`.

**Step 2: Rimuovere le route v1**

Eliminare da `config/routes.rb`:

```ruby
namespace :v1 do
  resource :me, only: [:show], controller: 'me'
  resources :search, only: [:index]
  resources :appunti, only: [:create]
  resources :documenti, only: [:create]
  resources :libri, only: [:index] do
    resources :imports, only: [:create], controller: 'libri/imports'
  end
  resources :persone, only: [:index] do
    resources :imports, only: [:create], controller: 'persone/imports'
  end
  resources :clienti, only: [] do
    resources :imports, only: [:create], controller: 'clienti/imports'
  end
  namespace :stats do
    get :adozioni, to: 'adozioni#index'
  end
end
```

**Step 3: Eliminare i controller v1**

```bash
rm -rf app/controllers/api/v1/
```

**Step 4: Run full test suite**

```bash
docker exec prova-app-1 bin/rails test
```

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove API v1 controllers and routes (replaced by respond_to JSON + /api/ endpoints)"
```

---

### Task 6: Aggiornare CLI Go

**Files:**
- Modify: `/home/paolotax/rails_2023/scagnozz-cli/internal/client/client.go`
- Modify: `/home/paolotax/rails_2023/scagnozz-cli/internal/mcp/tools.go`

Aggiornare gli URL nel CLI Go:

| Prima | Dopo |
|-------|------|
| `GET /api/v1/me` | `GET /api/me` |
| `GET /api/v1/search` | `GET /api/search` |
| `GET /api/v1/persone` | `GET /{account_id}/persone.json` |
| `GET /api/v1/libri` | `GET /{account_id}/libri.json` |
| `POST /api/v1/appunti` | `POST /{account_id}/appunti.json` |
| `POST /api/v1/documenti` | `POST /{account_id}/documenti.json` |
| `POST /api/v1/libri/:id/imports` | `POST /{account_id}/imports.json` (type=libri) |
| `POST /api/v1/persone/imports` | `POST /{account_id}/imports.json` (type=persone) |
| `POST /api/v1/clienti/imports` | `POST /{account_id}/imports.json` (type=clienti) |
| `GET /api/v1/stats/adozioni` | `GET /api/stats/adozioni` |

Il CLI deve:
1. Salvare `account_id` nel config (ottenuto da `/api/me`)
2. Usarlo come prefisso nelle URL delle risorse account-scoped

**Nota:** Questo task va fatto **dopo** aver verificato che tutti gli endpoint funzionano. Richiede ricompilazione del binario Go.

---

## Riepilogo route finali

```
# Endpoint speciali (senza account scope)
POST /api/mcp                    → MCP server
GET  /api/me                     → profilo utente
GET  /api/search                 → ricerca unificata
GET  /api/stats/adozioni         → stats MIUR
POST /api/whatsapp/contacts      → webhook

# CRUD risorse (account-scoped, respond_to JSON)
GET    /:account_id/appunti.json
POST   /:account_id/appunti.json
GET    /:account_id/appunti/:id.json
PATCH  /:account_id/appunti/:id.json
DELETE /:account_id/appunti/:id.json

# ... idem per documenti, tappe, giri, clienti, persone, scuole, libri

# Import unificato
POST   /:account_id/imports.json  (type=persone|libri|clienti)
```
