# API Imports MCP — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add CRUD-style import API endpoints for libri, clienti, persone — consumed by Scagnozz MCP tools. Accept fuzzy or rigid input, normalize, deduplicate, upsert or skip.

**Architecture:** Each resource gets a nested `imports` controller (`Api::V1::Libri::ImportsController`) that delegates to a service object (`Libri::Importer`). The Importer follows the same pattern as `Persone::Importer`: initialize with params → `import` → `.ok?` / `.result`. Batch is handled in the same endpoint — if the body contains an array key (`libri`, `clienti`, `persone`), it's batch.

**Tech Stack:** Rails API controllers, `ActionController::API`, `Api::TokenAuthenticatable`, service objects, Minitest.

---

### Task 1: Libri::Importer — test

**Files:**
- Create: `test/models/libri/importer_test.rb`
- Reference: `app/models/persone/importer.rb`, `app/services/imports/libri_processor.rb`

**Step 1: Write the test file**

```ruby
# test/models/libri/importer_test.rb
require "test_helper"

class Libri::ImporterTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :editori, :categorie

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    Current.user = @user
    Current.account = @account
  end

  # --- Single import: create ---

  test "creates libro with fuzzy input" do
    importer = Libri::Importer.new(
      isbn: "978-88-08-19900-0",
      titolo: "Nuovo Libro Test",
      prezzo: "12.50",
      editore: editori(:one).editore,
      disciplina: "Matematica",
      classe: "3"
    ).import

    assert importer.ok?
    assert_equal "created", importer.action
    assert importer.result[:id].present?

    libro = Libro.find(importer.result[:id])
    assert_equal "9788808199000", libro.codice_isbn
    assert_equal 1250, libro.prezzo_in_cents
    assert_equal "Nuovo Libro Test", libro.titolo
    assert_equal 3, libro.classe
  end

  test "creates libro with rigid input" do
    importer = Libri::Importer.new(
      codice_isbn: "9788808199001",
      titolo: "Libro Rigido",
      prezzo_cents: 1500,
      editore_id: editori(:one).id
    ).import

    assert importer.ok?
    libro = Libro.find(importer.result[:id])
    assert_equal 1500, libro.prezzo_in_cents
  end

  test "assigns default categoria when not specified" do
    importer = Libri::Importer.new(
      isbn: "9788808199002",
      titolo: "Senza Categoria"
    ).import

    assert importer.ok?
    libro = Libro.find(importer.result[:id])
    assert libro.categoria.present?
    assert_equal "non classificato", libro.categoria.nome_categoria
  end

  test "creates editore if not found" do
    importer = Libri::Importer.new(
      isbn: "9788808199003",
      titolo: "Editore Nuovo",
      editore: "Editore Inesistente XYZ"
    ).import

    assert importer.ok?
    libro = Libro.find(importer.result[:id])
    assert_equal "Editore Inesistente XYZ", libro.editore.editore
  end

  # --- Single import: update (on_conflict: update) ---

  test "updates existing libro by isbn" do
    Libri::Importer.new(isbn: "9788808199010", titolo: "Originale", prezzo: "10.00").import

    importer = Libri::Importer.new(
      isbn: "9788808199010",
      titolo: "Aggiornato",
      prezzo: "15.00",
      on_conflict: "update"
    ).import

    assert importer.ok?
    assert_equal "updated", importer.action
    libro = Libro.find(importer.result[:id])
    assert_equal "Aggiornato", libro.titolo
    assert_equal 1500, libro.prezzo_in_cents
  end

  # --- Single import: skip ---

  test "skips existing libro when on_conflict skip" do
    Libri::Importer.new(isbn: "9788808199020", titolo: "Originale").import

    importer = Libri::Importer.new(
      isbn: "9788808199020",
      titolo: "Non Dovrebbe Cambiare",
      on_conflict: "skip"
    ).import

    assert importer.ok?
    assert_equal "skipped", importer.action
    libro = Libro.find(importer.result[:id])
    assert_equal "Originale", libro.titolo
  end

  # --- Errors ---

  test "fails without isbn" do
    importer = Libri::Importer.new(titolo: "Senza ISBN").import

    refute importer.ok?
    assert_match(/isbn/i, importer.result[:error])
  end

  # --- Batch ---

  test "import_batch creates multiple libri" do
    result = Libri::Importer.import_batch([
      { isbn: "9788808199030", titolo: "Batch 1", prezzo: "10.00" },
      { isbn: "9788808199031", titolo: "Batch 2", prezzo: "12.00" }
    ])

    assert_equal 2, result[:imported]
    assert_equal 0, result[:errors].size
  end

  test "import_batch with on_conflict skip" do
    Libri::Importer.new(isbn: "9788808199040", titolo: "Esistente").import

    result = Libri::Importer.import_batch([
      { isbn: "9788808199040", titolo: "Skip" },
      { isbn: "9788808199041", titolo: "Nuovo" }
    ], on_conflict: "skip")

    assert_equal 1, result[:imported]
    assert_equal 1, result[:skipped]
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/libri/importer_test.rb`
Expected: Error — `Libri::Importer` not defined

**Step 3: Commit**

```bash
git add test/models/libri/importer_test.rb
git commit -m "test: add Libri::Importer tests"
```

---

### Task 2: Libri::Importer — implementation

**Files:**
- Create: `app/models/libri/importer.rb`
- Reference: `app/models/persone/importer.rb`, `app/services/imports/libri_processor.rb`

**Step 1: Write the importer**

```ruby
# app/models/libri/importer.rb
class Libri::Importer
  include ActiveModel::Model

  attr_reader :result, :action

  def initialize(**params)
    @params = params.stringify_keys
    @on_conflict = @params.delete("on_conflict") || "update"
  end

  def import
    normalize_params!
    validate_params! && find_or_create_libro
    self
  end

  def ok?
    @error.nil?
  end

  def batch_result
    {
      imported: action == "created" ? 1 : 0,
      updated: action == "updated" ? 1 : 0,
      skipped: action == "skipped" ? 1 : 0,
      errors: ok? ? [] : [result[:error]]
    }
  end

  def self.import_batch(items, on_conflict: "update")
    counters = { imported: 0, updated: 0, skipped: 0, errors: [] }
    items.each_with_index do |item, i|
      r = new(**item.symbolize_keys, on_conflict: on_conflict).import
      case r.action
      when "created" then counters[:imported] += 1
      when "updated" then counters[:updated] += 1
      when "skipped" then counters[:skipped] += 1
      else counters[:errors] << "riga #{i + 1}: #{r.result[:error]}"
      end
    end
    counters
  end

  private

  def normalize_params!
    @isbn = normalize_isbn(@params["isbn"] || @params["codice_isbn"])
    @titolo = @params["titolo"]&.strip
    @prezzo_cents = normalize_prezzo(@params["prezzo"] || @params["prezzo_cents"])
    @editore_value = @params["editore"] || @params["editore_id"]
    @categoria_value = @params["categoria"]
    @disciplina = @params["disciplina"]&.strip
    @classe = @params["classe"].present? ? @params["classe"].to_i : nil
    @collana = @params["collana"]&.strip
    @cm = @params["cm"]&.strip
  end

  def validate_params!
    return fail!("codice ISBN obbligatorio") if @isbn.blank?
    true
  end

  def find_or_create_libro
    libro = find_existing

    if libro && @on_conflict == "skip"
      @action = "skipped"
      @result = { ok: true, id: libro.id, action: @action }
      return
    end

    libro ||= build_new
    assign_attributes(libro)
    libro.save!

    @action = libro.previously_new_record? ? "created" : "updated"
    @result = { ok: true, id: libro.id, action: @action }
  rescue => e
    fail!(e.message)
  end

  def find_existing
    Current.account.libri.find_by(codice_isbn: @isbn)
  end

  def build_new
    Current.account.libri.new(user: Current.user)
  end

  def assign_attributes(libro)
    libro.codice_isbn = @isbn
    libro.titolo = @titolo if @titolo.present?
    libro.prezzo_in_cents = @prezzo_cents if @prezzo_cents
    libro.disciplina = @disciplina if @disciplina.present?
    libro.classe = @classe if @classe
    libro.collana = @collana if @collana.present?
    libro.cm = @cm if @cm.present?
    resolve_editore(libro)
    resolve_categoria(libro)
  end

  def resolve_editore(libro)
    return if @editore_value.blank?

    if @editore_value.is_a?(Integer) || @editore_value.to_s.match?(/\A\d+\z/)
      libro.editore_id = @editore_value.to_i
    else
      libro.editore = Editore.find_or_create_by!(editore: @editore_value)
    end
  end

  def resolve_categoria(libro)
    categoria_name = @categoria_value
    libro.categoria = Categoria.resolve(categoria_name, user: Current.user, account: Current.account)
  end

  def normalize_isbn(value)
    return nil if value.blank?
    value.to_s.gsub(/[\s\-]/, "")
  end

  def normalize_prezzo(value)
    return nil if value.blank?
    return value.to_i if value.is_a?(Integer)

    cleaned = value.to_s.gsub(",", ".").gsub(/[^\d.]/, "")
    (BigDecimal(cleaned) * 100).to_i
  rescue ArgumentError
    nil
  end

  def fail!(message)
    @error = message
    @action = nil
    @result = { ok: false, error: message }
    false
  end
end
```

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/models/libri/importer_test.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add app/models/libri/importer.rb
git commit -m "feat: add Libri::Importer with fuzzy input normalization"
```

---

### Task 3: Clienti::Importer — test

**Files:**
- Create: `test/models/clienti/importer_test.rb`

**Step 1: Write the test file**

```ruby
# test/models/clienti/importer_test.rb
require "test_helper"

class Clienti::ImporterTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships

  setup do
    @user = users(:one)
    @account = accounts(:fizzy)
    Current.user = @user
    Current.account = @account
  end

  test "creates cliente with fuzzy input" do
    importer = Clienti::Importer.new(
      nome: "Mario Rossi",
      piva: "12345678901",
      indirizzo: "Via Roma 1",
      cap: "00100",
      citta: "Roma",
      provincia: "RM",
      email: "mario@example.com"
    ).import

    assert importer.ok?
    assert_equal "created", importer.action

    cliente = Cliente.find(importer.result[:id])
    assert_equal "Mario Rossi", cliente.denominazione
    assert_equal "12345678901", cliente.partita_iva
    assert_equal "Roma", cliente.comune
  end

  test "creates cliente with rigid input" do
    importer = Clienti::Importer.new(
      denominazione: "Libreria ABC",
      partita_iva: "98765432109",
      comune: "Milano"
    ).import

    assert importer.ok?
    cliente = Cliente.find(importer.result[:id])
    assert_equal "Libreria ABC", cliente.denominazione
  end

  test "updates existing cliente by partita_iva" do
    Clienti::Importer.new(denominazione: "Vecchio Nome", piva: "11111111111").import

    importer = Clienti::Importer.new(
      denominazione: "Nuovo Nome",
      piva: "11111111111",
      on_conflict: "update"
    ).import

    assert importer.ok?
    assert_equal "updated", importer.action
    cliente = Cliente.find(importer.result[:id])
    assert_equal "Nuovo Nome", cliente.denominazione
  end

  test "skips existing cliente when on_conflict skip" do
    Clienti::Importer.new(denominazione: "Originale", piva: "22222222222").import

    importer = Clienti::Importer.new(
      denominazione: "Non Cambia",
      piva: "22222222222",
      on_conflict: "skip"
    ).import

    assert importer.ok?
    assert_equal "skipped", importer.action
    cliente = Cliente.find(importer.result[:id])
    assert_equal "Originale", cliente.denominazione
  end

  test "deduplicates by codice_fiscale when no partita_iva" do
    Clienti::Importer.new(denominazione: "CF Test", cf: "RSSMRA80A01H501U").import

    importer = Clienti::Importer.new(
      denominazione: "CF Aggiornato",
      cf: "RSSMRA80A01H501U",
      on_conflict: "update"
    ).import

    assert importer.ok?
    assert_equal "updated", importer.action
  end

  test "fails without denominazione or nome" do
    importer = Clienti::Importer.new(piva: "33333333333").import
    refute importer.ok?
  end

  test "import_batch creates multiple clienti" do
    result = Clienti::Importer.import_batch([
      { nome: "Batch 1", piva: "44444444441" },
      { nome: "Batch 2", piva: "44444444442" }
    ])

    assert_equal 2, result[:imported]
    assert_equal 0, result[:errors].size
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/clienti/importer_test.rb`
Expected: Error — `Clienti::Importer` not defined

**Step 3: Commit**

```bash
git add test/models/clienti/importer_test.rb
git commit -m "test: add Clienti::Importer tests"
```

---

### Task 4: Clienti::Importer — implementation

**Files:**
- Create: `app/models/clienti/importer.rb`

**Step 1: Write the importer**

```ruby
# app/models/clienti/importer.rb
class Clienti::Importer
  include ActiveModel::Model

  attr_reader :result, :action

  def initialize(**params)
    @params = params.stringify_keys
    @on_conflict = @params.delete("on_conflict") || "update"
  end

  def import
    normalize_params!
    validate_params! && find_or_create_cliente
    self
  end

  def ok?
    @error.nil?
  end

  def batch_result
    {
      imported: action == "created" ? 1 : 0,
      updated: action == "updated" ? 1 : 0,
      skipped: action == "skipped" ? 1 : 0,
      errors: ok? ? [] : [result[:error]]
    }
  end

  def self.import_batch(items, on_conflict: "update")
    counters = { imported: 0, updated: 0, skipped: 0, errors: [] }
    items.each_with_index do |item, i|
      r = new(**item.symbolize_keys, on_conflict: on_conflict).import
      case r.action
      when "created" then counters[:imported] += 1
      when "updated" then counters[:updated] += 1
      when "skipped" then counters[:skipped] += 1
      else counters[:errors] << "riga #{i + 1}: #{r.result[:error]}"
      end
    end
    counters
  end

  private

  def normalize_params!
    @denominazione = (@params["denominazione"] || @params["nome"] || @params["ragione_sociale"])&.strip
    @partita_iva = normalize_tax_id(@params["partita_iva"] || @params["piva"])
    @codice_fiscale = (@params["codice_fiscale"] || @params["cf"])&.strip&.upcase
    @indirizzo = @params["indirizzo"]&.strip
    @numero_civico = @params["numero_civico"]&.strip
    @cap = @params["cap"]&.strip
    @comune = (@params["comune"] || @params["citta"])&.strip
    @provincia = @params["provincia"]&.strip
    @email = @params["email"]&.strip&.downcase
    @telefono = @params["telefono"]&.strip
    @pec = @params["pec"]&.strip&.downcase
    @indirizzo_telematico = (@params["indirizzo_telematico"] || @params["sdi"])&.strip
    @tipo_cliente = @params["tipo_cliente"]&.strip
    @cognome = @params["cognome"]&.strip
    @nome_persona = @params["nome_persona"]&.strip
  end

  def validate_params!
    return fail!("denominazione o nome obbligatorio") if @denominazione.blank?
    true
  end

  def find_or_create_cliente
    cliente = find_existing

    if cliente && @on_conflict == "skip"
      @action = "skipped"
      @result = { ok: true, id: cliente.id, action: @action }
      return
    end

    cliente ||= build_new
    assign_attributes(cliente)
    cliente.save!

    @action = cliente.previously_new_record? ? "created" : "updated"
    @result = { ok: true, id: cliente.id, action: @action }
  rescue => e
    fail!(e.message)
  end

  def find_existing
    scope = Current.account.clienti
    if @partita_iva.present?
      scope.find_by(partita_iva: @partita_iva)
    elsif @codice_fiscale.present?
      scope.find_by(codice_fiscale: @codice_fiscale)
    end
  end

  def build_new
    Current.account.clienti.new(user: Current.user)
  end

  def assign_attributes(cliente)
    cliente.denominazione = @denominazione if @denominazione.present?
    cliente.partita_iva = @partita_iva if @partita_iva.present?
    cliente.codice_fiscale = @codice_fiscale if @codice_fiscale.present?
    cliente.indirizzo = @indirizzo if @indirizzo.present?
    cliente.numero_civico = @numero_civico if @numero_civico.present?
    cliente.cap = @cap if @cap.present?
    cliente.comune = @comune if @comune.present?
    cliente.provincia = @provincia if @provincia.present?
    cliente.email = @email if @email.present?
    cliente.telefono = @telefono if @telefono.present?
    cliente.pec = @pec if @pec.present?
    cliente.indirizzo_telematico = @indirizzo_telematico if @indirizzo_telematico.present?
    cliente.tipo_cliente = @tipo_cliente if @tipo_cliente.present?
    cliente.cognome = @cognome if @cognome.present?
    cliente.nome = @nome_persona if @nome_persona.present?
  end

  def normalize_tax_id(value)
    return nil if value.blank?
    value.to_s.gsub(/[\s\-]/, "")
  end

  def fail!(message)
    @error = message
    @action = nil
    @result = { ok: false, error: message }
    false
  end
end
```

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/models/clienti/importer_test.rb`
Expected: All pass

**Step 3: Commit**

```bash
git add app/models/clienti/importer.rb
git commit -m "feat: add Clienti::Importer with fuzzy input normalization"
```

---

### Task 5: API controllers — test

**Files:**
- Create: `test/controllers/api/v1/libri/imports_controller_test.rb`
- Create: `test/controllers/api/v1/clienti/imports_controller_test.rb`
- Create: `test/controllers/api/v1/persone/imports_controller_test.rb`
- Reference: `app/controllers/concerns/api/token_authenticatable.rb`

**Step 1: Check how token auth works for test setup**

Run: `docker exec prova-app-1 cat app/controllers/concerns/api/token_authenticatable.rb`

**Step 2: Write libri imports controller test**

```ruby
# test/controllers/api/v1/libri/imports_controller_test.rb
require "test_helper"

class Api::V1::Libri::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie

  setup do
    @user = users(:one)
    @token = @user.api_tokens.first&.token || create_api_token(@user)
    @headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
  end

  test "imports single libro" do
    assert_difference "Libro.count", 1 do
      post api_v1_libro_imports_path(libro_id: 0),
        params: { isbn: "9788808100001", titolo: "Test API", prezzo: "10.00" }.to_json,
        headers: @headers
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "imports batch of libri" do
    assert_difference "Libro.count", 2 do
      post api_v1_libro_imports_path(libro_id: 0),
        params: {
          libri: [
            { isbn: "9788808100002", titolo: "Batch A" },
            { isbn: "9788808100003", titolo: "Batch B" }
          ]
        }.to_json,
        headers: @headers
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["imported"]
  end

  test "returns 401 without token" do
    post api_v1_libro_imports_path(libro_id: 0),
      params: { isbn: "9788808100004", titolo: "No Auth" }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :unauthorized
  end

  private

  def create_api_token(user)
    # Adjust based on actual token model
    user.api_tokens.create!(token: SecureRandom.hex(32)).token
  end
end
```

**Step 3: Write clienti imports controller test**

```ruby
# test/controllers/api/v1/clienti/imports_controller_test.rb
require "test_helper"

class Api::V1::Clienti::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @user = users(:one)
    @token = @user.api_tokens.first&.token || create_api_token(@user)
    @headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
  end

  test "imports single cliente" do
    assert_difference "Cliente.count", 1 do
      post api_v1_cliente_imports_path(cliente_id: 0),
        params: { nome: "Test Cliente", piva: "99999999901" }.to_json,
        headers: @headers
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["imported"]
  end

  test "imports batch of clienti" do
    assert_difference "Cliente.count", 2 do
      post api_v1_cliente_imports_path(cliente_id: 0),
        params: {
          clienti: [
            { nome: "Batch A", piva: "99999999902" },
            { nome: "Batch B", piva: "99999999903" }
          ]
        }.to_json,
        headers: @headers
    end

    assert_response :success
  end

  private

  def create_api_token(user)
    user.api_tokens.create!(token: SecureRandom.hex(32)).token
  end
end
```

**Step 4: Write persone imports controller test**

```ruby
# test/controllers/api/v1/persone/imports_controller_test.rb
require "test_helper"

class Api::V1::Persone::ImportsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @user = users(:one)
    @token = @user.api_tokens.first&.token || create_api_token(@user)
    @headers = { "Authorization" => "Bearer #{@token}", "Content-Type" => "application/json" }
  end

  test "imports single persona" do
    post api_v1_persona_imports_path(persona_id: 0),
      params: { cognome: "Verdi", nome: "Giuseppe", scuola: scuole(:one).denominazione }.to_json,
      headers: @headers

    assert_response :success
  end

  test "imports batch of persone" do
    scuola_nome = scuole(:one).denominazione
    post api_v1_persona_imports_path(persona_id: 0),
      params: {
        persone: [
          { cognome: "Bianchi", nome: "Luca", scuola: scuola_nome },
          { cognome: "Neri", nome: "Anna", scuola: scuola_nome }
        ]
      }.to_json,
      headers: @headers

    assert_response :success
  end

  private

  def create_api_token(user)
    user.api_tokens.create!(token: SecureRandom.hex(32)).token
  end
end
```

**Step 5: Commit**

```bash
git add test/controllers/api/v1/libri/ test/controllers/api/v1/clienti/ test/controllers/api/v1/persone/
git commit -m "test: add API imports controller tests"
```

---

### Task 6: API controllers + routes

**Files:**
- Create: `app/controllers/api/v1/libri/imports_controller.rb`
- Create: `app/controllers/api/v1/clienti/imports_controller.rb`
- Create: `app/controllers/api/v1/persone/imports_controller.rb`
- Modify: `config/routes.rb` (api namespace block, ~lines 520-536)
- Modify: `app/controllers/api/v1/persone_controller.rb` (remove import actions)

**Step 1: Create libri imports controller**

```ruby
# app/controllers/api/v1/libri/imports_controller.rb
module Api
  module V1
    module Libri
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable

        before_action :authenticate_api!

        # POST /api/v1/libri/imports
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
          params.except(:controller, :action, :libro_id, :libri, :format)
                .permit!.to_h.symbolize_keys
                .merge(on_conflict: on_conflict)
        end
      end
    end
  end
end
```

**Step 2: Create clienti imports controller**

```ruby
# app/controllers/api/v1/clienti/imports_controller.rb
module Api
  module V1
    module Clienti
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable

        before_action :authenticate_api!

        # POST /api/v1/clienti/imports
        def create
          if params[:clienti].present?
            items = params[:clienti].map { |c| c.permit!.to_h }
            result = ::Clienti::Importer.import_batch(items, on_conflict: on_conflict)
          else
            importer = ::Clienti::Importer.new(**import_params).import
            result = importer.batch_result
          end

          render json: result
        end

        private

        def on_conflict
          params[:on_conflict] || "update"
        end

        def import_params
          params.except(:controller, :action, :cliente_id, :clienti, :format)
                .permit!.to_h.symbolize_keys
                .merge(on_conflict: on_conflict)
        end
      end
    end
  end
end
```

**Step 3: Create persone imports controller**

```ruby
# app/controllers/api/v1/persone/imports_controller.rb
module Api
  module V1
    module Persone
      class ImportsController < ActionController::API
        include Api::TokenAuthenticatable

        before_action :authenticate_api!

        # POST /api/v1/persone/imports
        def create
          if params[:persone].present?
            items = params[:persone].map { |p| p.permit!.to_h }
            result = ::Persone::Importer.import_batch(items)
          else
            importer = ::Persone::Importer.new(**import_params).import
            result = importer.result
          end

          render json: result
        end

        private

        def import_params
          params.except(:controller, :action, :persona_id, :persone, :format)
                .permit(:cognome, :nome, :email, :cellulare, :telefono, :scuola, :ruolo, classi: [])
                .to_h.symbolize_keys
        end
      end
    end
  end
end
```

**Step 4: Update routes**

In `config/routes.rb`, replace the current API block (~lines 520-536):

```ruby
namespace :api do
  post "whatsapp/contacts", to: "whatsapp#create"
  namespace :v1 do
    resource :me, only: [:show], controller: "me"
    resources :appunti, only: [:create]
    resources :libri, only: [:index] do
      resources :imports, only: [:create], controller: "api/v1/libri/imports"
    end
    resources :documenti, only: [:create]
    resources :persone, only: [:index] do
      resources :imports, only: [:create], controller: "api/v1/persone/imports"
    end
    resources :clienti, only: [] do
      resources :imports, only: [:create], controller: "api/v1/clienti/imports"
    end
    resources :search, only: [:index]
  end
end
```

**Step 5: Remove import/import_batch from PersoneController**

Remove the `import` and `import_batch` actions and their private method `import_params` from `app/controllers/api/v1/persone_controller.rb`. Keep `index` and `format_persona`.

**Step 6: Run all tests**

Run: `docker exec prova-app-1 bin/rails test test/controllers/api/v1/`
Expected: All pass

**Step 7: Commit**

```bash
git add app/controllers/api/v1/libri/ app/controllers/api/v1/clienti/ app/controllers/api/v1/persone/
git add config/routes.rb app/controllers/api/v1/persone_controller.rb
git commit -m "feat: add CRUD import API endpoints for libri, clienti, persone"
```

---

### Task 7: Run full test suite and verify

**Step 1: Run all tests**

Run: `docker exec prova-app-1 bin/rails test`
Expected: All pass, no regressions

**Step 2: Manual smoke test with curl**

```bash
# Test libri single import
docker exec prova-app-1 bin/rails runner "puts User.first.api_tokens.first.token"

curl -X POST http://localhost:3000/api/v1/libri/imports \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"isbn": "9781234567890", "titolo": "Test Curl", "prezzo": "15.00"}'
```

**Step 3: Check routes are correct**

Run: `docker exec prova-app-1 bin/rails routes -g imports`
Expected: Shows the 3 import routes
