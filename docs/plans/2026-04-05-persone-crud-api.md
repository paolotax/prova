# Persone CRUD API — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Aggiungere respond_to JSON al PersoneController esistente (pattern Clienti), con formato envelope per index e formato diretto per show/create/update/destroy.

**Architecture:** Il PersoneController viene esteso con `format.json` su tutte le azioni CRUD. L'index JSON usa un envelope `{ ok, query, count, data, actions }` (compatibile LLM/chatbot). Show/create/update/destroy restituiscono la persona direttamente (pattern Clienti). Le query avanzate dall'API v1 (anno_corso, con_email, sort) vengono portate nell'index.

**Tech Stack:** Rails respond_to, Jbuilder views, Minitest integration tests

---

### Task 1: Jbuilder views per Persona

**Files:**
- Create: `app/views/persone/_persona.json.jbuilder`
- Create: `app/views/persone/show.json.jbuilder`
- Create: `app/views/persone/index.json.jbuilder`

**Step 1: Creare il partial `_persona.json.jbuilder`**

```ruby
json.extract! persona, :id, :cognome, :nome, :email, :cellulare, :telefono, :ruolo, :note, :scuola_id, :created_at, :updated_at
json.scuola persona.scuola&.denominazione
json.classi persona.classi do |classe|
  json.id classe.id
  json.display classe.to_combobox_display
  json.anno_corso classe.anno_corso
end
json.appuntabile_value "Persona:#{persona.id}"
json.url persona_url(persona, format: :json)
```

**Step 2: Creare `show.json.jbuilder`**

```ruby
json.partial! "persone/persona", persona: @persona
```

**Step 3: Creare `index.json.jbuilder`**

```ruby
json.ok true
json.query params[:q]
json.count @persone.size
json.data @persone do |persona|
  json.partial! "persone/persona", persona: persona
end
json.actions @persone.first(3) do |persona|
  json.name "crea_appunto"
  json.label "Crea appunto per #{persona.nome_completo}"
  json.params do
    json.appuntabile_type "Persona"
    json.appuntabile_id persona.id
  end
end
```

**Step 4: Verificare che i file esistano**

Run: `ls app/views/persone/*.json.jbuilder`
Expected: 3 file elencati

---

### Task 2: Aggiornare PersoneController con respond_to JSON

**Files:**
- Modify: `app/controllers/persone_controller.rb`

**Step 1: Aggiornare `index` con branch JSON**

Aggiungere skip del filter per JSON (come Clienti) e il branch `request.format.json?`:

```ruby
skip_before_action :set_filter, :set_user_filtering, if: -> { request.format.json? }

def index
  if request.format.json?
    @persone = Current.account.persone.includes(:scuola, :classi)

    if params[:anno_corso].present?
      anni = params[:anno_corso].split(",").map(&:strip).map(&:to_i)
      @persone = @persone.joins(:classi).where(classi: { anno_corso: anni }).distinct
    end

    @persone = @persone.where.not(email: [nil, ""]) if params[:con_email].present?
    @persone = @persone.where(scuola_id: params[:scuola_id]) if params[:scuola_id].present?

    if params[:q].present?
      params[:q].split(/\s+/).each do |word|
        @persone = @persone.where("persone.cognome ILIKE :q OR persone.nome ILIKE :q", q: "%#{word}%")
      end
    end

    limit = (params[:limit] || 50).to_i.clamp(1, 200)
    order = params[:sort] == "recenti" ? { created_at: :desc } : { cognome: :asc, nome: :asc }
    @persone = @persone.order(order).limit(limit)
  else
    @total_count = @filter.persone.count
    set_page_and_extract_portion_from @filter.persone
  end

  respond_to do |format|
    format.html
    format.turbo_stream
    format.json
  end
end
```

**Step 2: Aggiornare `show` — sostituire render inline con jbuilder**

```ruby
def show
  load_prev_next
  @appunti = @persona.appunti.includes(entry: [:goldness, :closure, :not_now]).order(created_at: :desc)

  respond_to do |format|
    format.html
    format.turbo_stream
    format.json
  end
end
```

**Step 3: Aggiornare `create` — aggiungere format.json**

```ruby
def create
  @persona = Current.account.persone.new(persona_params.except(:classe_ids, :materia))

  respond_to do |format|
    if @persona.save
      format.html { redirect_to persona_path(@persona), notice: "#{@persona.nome_completo} aggiunto" }
      format.json { render :show, status: :created, location: @persona }
    else
      format.html { redirect_back fallback_location: persone_path, alert: @persona.errors.full_messages.join(", ") }
      format.json { render json: @persona.errors, status: :unprocessable_entity }
    end
  end
end
```

**Step 4: Aggiornare `update` — aggiungere format.json**

Nel blocco `respond_to` del success path, aggiungere:

```ruby
format.json { render :show, status: :ok, location: @persona }
```

E nel failure path:

```ruby
format.json { render json: @persona.errors, status: :unprocessable_entity }
```

**Step 5: Aggiornare `destroy` — aggiungere format.json**

```ruby
def destroy
  nome = @persona.nome_completo
  scuola = @persona.scuola
  @persona.destroy

  respond_to do |format|
    if scuola.present?
      format.html { redirect_to scuola_path(scuola), notice: "#{nome} eliminato" }
    else
      format.html { redirect_to persone_path, notice: "#{nome} eliminato" }
    end
    format.json { head :no_content }
  end
end
```

**Step 6: Eseguire i test esistenti per verificare che HTML non sia rotto**

Run: `docker exec prova-app-1 bin/rails test test/controllers/ -v 2>&1 | tail -20`
Expected: nessun test fallito relativo a persone

---

### Task 3: Test di integrazione JSON

**Files:**
- Create: `test/controllers/persone_json_test.rb`

**Step 1: Scrivere i test**

```ruby
require "test_helper"

class PersoneJsonTest < ActionDispatch::IntegrationTest
  fixtures :users, :accounts, :memberships, :persone, :scuole

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    @membership = memberships(:alice_fizzy)
    @token = @membership.access_tokens.create!(description: "Test API")
    @persona = persone(:persona_fizzy)
    @headers = { "Authorization" => "Bearer #{@token.token}" }
  end

  # Auth

  test "returns 401 without token" do
    get persone_path(account_id: @account.id), as: :json
    assert_response :unauthorized
  end

  test "authenticates with bearer token" do
    get persone_path(account_id: @account.id), as: :json, headers: @headers
    assert_response :success
  end

  # Index

  test "index returns envelope JSON" do
    get persone_path(account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_kind_of Array, json["data"]
    assert json["count"].is_a?(Integer)
  end

  test "index supports search with q param" do
    get persone_path(account_id: @account.id, q: @persona.cognome.first(4)), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].any? { |p| p["id"] == @persona.id }
  end

  test "index supports limit param" do
    get persone_path(account_id: @account.id, limit: 1), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["data"].length <= 1
  end

  test "index supports scuola_id filter" do
    get persone_path(account_id: @account.id, scuola_id: @persona.scuola_id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["data"].each { |p| assert_equal @persona.scuola_id, p["scuola_id"] }
  end

  test "index supports con_email filter" do
    get persone_path(account_id: @account.id, con_email: true), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    json["data"].each { |p| assert p["email"].present? }
  end

  # Show

  test "show returns persona JSON" do
    get persona_path(@persona, account_id: @account.id), as: :json, headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @persona.id, json["id"]
    assert_equal @persona.cognome, json["cognome"]
    assert_equal @persona.nome, json["nome"]
    assert json.key?("classi")
    assert json.key?("url")
  end

  # Create

  test "create returns created persona" do
    assert_difference "Persona.count", 1 do
      post persone_path(account_id: @account.id), as: :json,
        params: { persona: { cognome: "Neri", nome: "Paolo", ruolo: "docente", email: "neri@test.it" } },
        headers: @headers
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "Neri", json["cognome"]
    assert_equal "Paolo", json["nome"]
  end

  test "create returns errors for invalid data" do
    post persone_path(account_id: @account.id), as: :json,
      params: { persona: { cognome: "", nome: "" } },
      headers: @headers

    assert_response :unprocessable_entity
  end

  # Update

  test "update modifies persona" do
    patch persona_path(@persona, account_id: @account.id), as: :json,
      params: { persona: { email: "nuovo@email.it" } },
      headers: @headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "nuovo@email.it", json["email"]
  end

  # Destroy

  test "destroy removes persona" do
    persona = @account.persone.create!(cognome: "Da Eliminare")

    assert_difference "Persona.count", -1 do
      delete persona_path(persona, account_id: @account.id), as: :json, headers: @headers
    end

    assert_response :no_content
  end
end
```

**Step 2: Eseguire i test**

Run: `docker exec prova-app-1 bin/rails test test/controllers/persone_json_test.rb -v`
Expected: tutti i test passano

**Step 3: Commit**

```bash
git add app/views/persone/_persona.json.jbuilder app/views/persone/show.json.jbuilder app/views/persone/index.json.jbuilder app/controllers/persone_controller.rb test/controllers/persone_json_test.rb
git commit -m "feat: add JSON CRUD API to PersoneController with envelope index format"
```
