# Appunti::AppuntoCreator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unificare i 4 percorsi di creazione appunto (web, mobile, API, WhatsApp) in un unico PORO `Appunti::AppuntoCreator`.

**Architecture:** PORO con `ActiveModel::Model` in `app/models/appunti/appunto_creator.rb`. I controller delegano al creator per tutta la logica di creazione (find-or-create persona, risoluzione appuntabile, build appunto, publish opzionale). Ogni chiamata crea un nuovo appunto drafted.

**Tech Stack:** Rails 8.1, ActiveModel::Model, Minitest, fixtures

---

### Task 1: Creare il PORO Appunti::AppuntoCreator con test

**Files:**
- Create: `app/models/appunti/appunto_creator.rb`
- Create: `test/models/appunti/appunto_creator_test.rb`
- Reference: `app/models/concerns/appuntabile.rb` (per `parse_appuntabile_value`)
- Reference: `app/models/appunto/statuses.rb` (per `publish`)
- Reference: `app/models/persona.rb` (per validazione cognome_o_nome)

**Step 1: Write the failing tests**

```ruby
# test/models/appunti/appunto_creator_test.rb
require "test_helper"

class Appunti::AppuntoCreatorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
    Current.account = @account
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  # --- Creazione base ---

  test "creates a drafted appunto with basic params" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Test appunto",
      content: "Contenuto di prova"
    )

    assert_difference "Appunto.count", 1 do
      creator.create
    end

    assert creator.appunto.persisted?
    assert creator.appunto.drafted?
    assert_equal "Test appunto", creator.appunto.nome
    assert_equal @user, creator.appunto.user
    assert_equal @account, creator.appunto.account
  end

  test "creates a new appunto every time (no find-or-initialize)" do
    creator1 = Appunti::AppuntoCreator.new(nome: "Primo")
    creator2 = Appunti::AppuntoCreator.new(nome: "Secondo")

    creator1.create
    creator2.create

    assert_not_equal creator1.appunto.id, creator2.appunto.id
    assert_equal 2, Appunto.drafted.where(user: @user).where("nome IN ('Primo', 'Secondo')").count
  end

  # --- Publish ---

  test "publishes appunto when publish is true" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Da pubblicare",
      content: "Testo",
      publish: true
    )
    creator.create

    assert creator.appunto.published?
  end

  test "keeps appunto drafted when publish is false" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Bozza",
      publish: false
    )
    creator.create

    assert creator.appunto.drafted?
  end

  # --- Appuntabile esplicito ---

  test "sets appuntabile from appuntabile_value Scuola" do
    scuola = scuole(:one)
    creator = Appunti::AppuntoCreator.new(
      nome: "Per scuola",
      appuntabile_value: "Scuola:#{scuola.id}"
    )
    creator.create

    assert_equal scuola, creator.appunto.appuntabile
  end

  test "sets appuntabile from appuntabile_value Classe" do
    classe = classi(:one)
    creator = Appunti::AppuntoCreator.new(
      nome: "Per classe",
      appuntabile_value: "Classe:#{classe.id}"
    )
    creator.create

    assert_equal classe, creator.appunto.appuntabile
  end

  test "sets appuntabile from appuntabile_value Persona" do
    persona = persone(:one)
    creator = Appunti::AppuntoCreator.new(
      nome: "Per persona",
      appuntabile_value: "Persona:#{persona.id}"
    )
    creator.create

    assert_equal persona, creator.appunto.appuntabile
  end

  # --- Persona find-or-create per cellulare (WhatsApp) ---

  test "finds existing persona by cellulare" do
    persona = persone(:one)
    creator = Appunti::AppuntoCreator.new(
      persona_cellulare: persona.cellulare,
      content: "Da WhatsApp"
    )

    assert_no_difference "Persona.count" do
      creator.create
    end

    assert_equal persona, creator.persona
  end

  test "creates new persona when cellulare not found" do
    creator = Appunti::AppuntoCreator.new(
      persona_cellulare: "3331234567",
      persona_nome: "Mario",
      content: "Da WhatsApp"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    assert_equal "Mario", creator.persona.nome
    assert_equal "3331234567", creator.persona.cellulare
  end

  # --- Persona creazione esplicita (form) ---

  test "creates persona with nome only" do
    creator = Appunti::AppuntoCreator.new(
      persona_nome: "Luca",
      content: "Appunto con persona"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    assert_equal "Luca", creator.persona.nome
  end

  test "creates persona with cognome only" do
    creator = Appunti::AppuntoCreator.new(
      persona_cognome: "Rossi",
      content: "Appunto con persona"
    )

    assert_difference "Persona.count", 1 do
      creator.create
    end

    assert_equal "Rossi", creator.persona.cognome
  end

  # --- Persona collegata a scuola ---

  test "links persona to scuola by scuola_nome" do
    scuola = scuole(:one)
    creator = Appunti::AppuntoCreator.new(
      persona_cellulare: "3339999999",
      persona_nome: "Nuovo",
      persona_scuola_nome: scuola.denominazione,
      content: "Da WhatsApp"
    )
    creator.create

    assert_equal scuola, creator.persona.scuola
  end

  # --- Risoluzione appuntabile da persona ---

  test "resolves appuntabile to persona scuola when no explicit appuntabile" do
    persona = persone(:one)
    # persona ha una scuola collegata
    skip("Persona fixture needs scuola") unless persona.scuola.present?

    creator = Appunti::AppuntoCreator.new(
      persona_cellulare: persona.cellulare,
      content: "Da WhatsApp"
    )
    creator.create

    assert_equal persona.scuola, creator.appunto.appuntabile
  end

  test "falls back to persona as appuntabile when persona has no scuola" do
    creator = Appunti::AppuntoCreator.new(
      persona_cellulare: "3330000001",
      persona_nome: "Senza scuola",
      content: "Da WhatsApp"
    )
    creator.create

    assert_equal creator.persona, creator.appunto.appuntabile
  end

  test "explicit appuntabile_value takes precedence over persona scuola" do
    scuola_esplicita = scuole(:one)
    creator = Appunti::AppuntoCreator.new(
      appuntabile_value: "Scuola:#{scuola_esplicita.id}",
      persona_cellulare: "3330000002",
      persona_nome: "Ignorato",
      content: "Appuntabile esplicito vince"
    )
    creator.create

    assert_equal scuola_esplicita, creator.appunto.appuntabile
  end

  # --- Parametri contatto ---

  test "passes telefono and email to appunto" do
    creator = Appunti::AppuntoCreator.new(
      nome: "Con contatti",
      telefono: "0612345678",
      email: "test@example.com"
    )
    creator.create

    assert_equal "0612345678", creator.appunto.telefono
    assert_equal "test@example.com", creator.appunto.email
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `docker exec prova-app-1 bin/rails test test/models/appunti/appunto_creator_test.rb`
Expected: FAIL — `NameError: uninitialized constant Appunti::AppuntoCreator`

**Step 3: Write the implementation**

```ruby
# app/models/appunti/appunto_creator.rb
class Appunti::AppuntoCreator
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Parametri appunto
  attribute :nome, :string
  attribute :content, :string
  attribute :appuntabile_value, :string
  attribute :telefono, :string
  attribute :email, :string
  attribute :publish, :boolean, default: false

  # Parametri persona
  attribute :persona_nome, :string
  attribute :persona_cognome, :string
  attribute :persona_cellulare, :string
  attribute :persona_email, :string
  attribute :persona_scuola_nome, :string

  attr_reader :appunto, :persona

  def create
    find_or_build_persona
    resolve_appuntabile
    build_appunto
    appunto.save && maybe_publish
    appunto
  end

  private

  def find_or_build_persona
    return unless persona_params_present?

    @persona = find_persona_by_cellulare if persona_cellulare.present?

    @persona ||= Current.account.persone.build(
      nome: persona_nome,
      cognome: persona_cognome,
      cellulare: persona_cellulare,
      email: persona_email
    )

    link_persona_to_scuola if persona_scuola_nome.present? && @persona.scuola.blank?

    @persona.save! if @persona.new_record? || @persona.changed?
  end

  def find_persona_by_cellulare
    cleaned = persona_cellulare.gsub(/\s/, "")
    Current.account.persone.find_by("cellulare = :tel OR telefono = :tel", tel: cleaned)
  end

  def link_persona_to_scuola
    scuola = Current.account.scuole.search_all_word(persona_scuola_nome).first
    @persona.scuola = scuola if scuola
  rescue PgSearch::EmptyQueryError
    nil
  end

  def resolve_appuntabile
    @resolved_appuntabile = if appuntabile_value.present?
      Appuntabile.find_appuntabile(appuntabile_value)
    elsif @persona&.scuola.present?
      @persona.scuola
    elsif @persona.present?
      @persona
    end
  end

  def build_appunto
    @appunto = Current.account.appunti.build(
      user: Current.user,
      nome: nome,
      content: content,
      telefono: telefono,
      email: email,
      appuntabile: @resolved_appuntabile
    )
  end

  def maybe_publish
    appunto.publish if publish && appunto.persisted?
  end

  def persona_params_present?
    persona_cellulare.present? || persona_nome.present? || persona_cognome.present?
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `docker exec prova-app-1 bin/rails test test/models/appunti/appunto_creator_test.rb`
Expected: PASS (some tests may need fixture adjustments — fix those)

**Step 5: Commit**

```bash
git add app/models/appunti/appunto_creator.rb test/models/appunti/appunto_creator_test.rb
git commit -m "feat: add Appunti::AppuntoCreator PORO for unified appunto creation"
```

---

### Task 2: Refactor AppuntiController per usare il creator

**Files:**
- Modify: `app/controllers/appunti_controller.rb` (lines 50-58, 64-73)
- Modify: `app/controllers/appunti/publications_controller.rb` (line 11)
- Test: `test/controllers/appunti_controller_test.rb` (se esiste)

**Step 1: Write/update the failing test**

Verifica che i test controller esistenti continuino a passare dopo il refactor. Se non ci sono test per `new`/`create`, aggiungere:

```ruby
# In test del controller, verificare che new/create creino un nuovo appunto drafted
test "new creates a drafted appunto and redirects" do
  assert_difference "Appunto.count", 1 do
    get new_appunto_url
  end
  appunto = Appunto.drafted.last
  assert_redirected_to appunto_url(appunto)
end
```

**Step 2: Run existing tests to verify baseline**

Run: `docker exec prova-app-1 bin/rails test test/controllers/appunti_controller_test.rb`

**Step 3: Refactor the controller**

In `app/controllers/appunti_controller.rb`, cambiare `new` e `create`:

```ruby
# Prima (da rimuovere):
def new
  @appunto = Current.user.draft_new_appunto(appuntabile: find_appuntabile)
  redirect_to @appunto
end

def create
  @appunto = Current.user.draft_new_appunto(appuntabile: find_appuntabile)
  redirect_to @appunto
end

# Dopo:
def new
  creator = Appunti::AppuntoCreator.new(appuntabile_value: find_appuntabile&.to_appuntabile_value)
  creator.create
  redirect_to creator.appunto
end

def create
  creator = Appunti::AppuntoCreator.new(appuntabile_value: find_appuntabile&.to_appuntabile_value)
  creator.create
  redirect_to creator.appunto
end
```

In `update`, cambiare il `publish_and_new`:

```ruby
# Prima:
new_appunto = current_user.draft_new_appunto

# Dopo:
creator = Appunti::AppuntoCreator.new
creator.create
new_appunto = creator.appunto
```

In `app/controllers/appunti/publications_controller.rb`, stessa modifica:

```ruby
# Prima:
new_appunto = current_user.draft_new_appunto

# Dopo:
creator = Appunti::AppuntoCreator.new
creator.create
new_appunto = creator.appunto
```

**Step 4: Run tests**

Run: `docker exec prova-app-1 bin/rails test test/controllers/appunti_controller_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/controllers/appunti_controller.rb app/controllers/appunti/publications_controller.rb
git commit -m "refactor: AppuntiController uses Appunti::AppuntoCreator"
```

---

### Task 3: Refactor Mobile::AppuntiController per usare il creator

**Files:**
- Modify: `app/controllers/mobile/appunti_controller.rb`

**Step 1: Run existing tests as baseline**

Run: `docker exec prova-app-1 bin/rails test test/controllers/mobile/`
(se non esiste la directory, saltare — il test principale è nel creator)

**Step 2: Refactor the controller**

```ruby
# app/controllers/mobile/appunti_controller.rb
module Mobile
  class AppuntiController < ApplicationController
    layout "mobile"

    before_action :require_account!

    def new
      @appunto = Appunto.new
    end

    def create
      creator = Appunti::AppuntoCreator.new(creator_params)
      creator.create

      if creator.appunto.persisted?
        redirect_to new_mobile_appunto_path, notice: "Appunto salvato come bozza!"
      else
        @appunto = creator.appunto
        render :new, status: :unprocessable_entity
      end
    end

    private

    def creator_params
      params.fetch(:appunto, {}).permit(
        :nome, :content, :appuntabile_value, :telefono, :email, attachments: []
      ).merge(persona_params).to_h
    end

    def persona_params
      return {} unless params[:persona].present?

      {
        persona_nome: params.dig(:persona, :nome),
        persona_cognome: params.dig(:persona, :cognome),
        persona_cellulare: params.dig(:persona, :cellulare),
        persona_email: params.dig(:persona, :email)
      }.compact
    end

    def require_account!
      return if Current.account.present?
      redirect_to accounts_path, alert: "Seleziona un account"
    end
  end
end
```

**Step 3: Run tests**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

**Step 4: Commit**

```bash
git add app/controllers/mobile/appunti_controller.rb
git commit -m "refactor: Mobile::AppuntiController uses Appunti::AppuntoCreator"
```

---

### Task 4: Refactor Api::V1::AppuntiController per usare il creator

**Files:**
- Modify: `app/controllers/api/v1/appunti_controller.rb`

**Step 1: Refactor the controller**

```ruby
# app/controllers/api/v1/appunti_controller.rb
module Api
  module V1
    class AppuntiController < ActionController::API
      include Api::TokenAuthenticatable

      before_action :authenticate_api!

      def create
        creator = Appunti::AppuntoCreator.new(creator_params)
        creator.create

        if creator.appunto.persisted?
          render json: {
            success: true,
            appunto_id: creator.appunto.id,
            nome: creator.appunto.nome,
            status: creator.appunto.status
          }, status: :created
        else
          render json: {
            success: false,
            errors: creator.appunto.errors.full_messages
          }, status: :unprocessable_entity
        end
      end

      private

      def creator_params
        permitted = params.fetch(:appunto, {}).permit(
          :nome, :content, :appuntabile_value, :telefono, :email, attachments: []
        )
        permitted[:publish] = params[:publish] if params[:publish].present?
        permitted.to_h
      end
    end
  end
end
```

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

**Step 3: Commit**

```bash
git add app/controllers/api/v1/appunti_controller.rb
git commit -m "refactor: Api::V1::AppuntiController uses Appunti::AppuntoCreator"
```

---

### Task 5: Refactor Api::WhatsappController per usare il creator

**Files:**
- Modify: `app/controllers/api/whatsapp_controller.rb`

**Step 1: Refactor the controller**

```ruby
# app/controllers/api/whatsapp_controller.rb
module Api
  class WhatsappController < ActionController::API
    include Api::TokenAuthenticatable

    before_action :authenticate_api!

    def create
      creator = Appunti::AppuntoCreator.new(
        content: params[:messaggio],
        persona_cellulare: params[:telefono],
        persona_nome: params[:nome].presence || "Sconosciuto",
        persona_scuola_nome: params[:scuola_nome],
        publish: true
      )
      creator.create

      if creator.appunto.persisted?
        render json: {
          success: true,
          persona_id: creator.persona&.id,
          appunto_id: creator.appunto.id,
          persona_nome: creator.persona&.nome_completo,
          scuola_nome: creator.appunto.appuntabile&.try(:denominazione)
        }, status: :created
      else
        render json: { success: false, error: creator.appunto.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
```

**Nota:** Il WhatsApp controller prima settava `nome: "WhatsApp - #{persona.nome_completo}"`. Con il creator, il nome non viene settato esplicitamente (sarà nil). Se vuoi mantenere quel pattern, aggiungere un callback nel creator o passare il nome dopo la creazione persona. Decisione da prendere in fase di implementazione.

**Step 2: Run tests**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

**Step 3: Commit**

```bash
git add app/controllers/api/whatsapp_controller.rb
git commit -m "refactor: Api::WhatsappController uses Appunti::AppuntoCreator"
```

---

### Task 6: Rimuovere User#draft_new_appunto e aggiornare test

**Files:**
- Modify: `app/models/user.rb` (lines 150-156 — rimuovere `draft_new_appunto`)
- Modify: `test/models/user_test.rb` (lines 35-59 — rimuovere test del draft)

**Step 1: Remove the method from User**

In `app/models/user.rb`, rimuovere:

```ruby
# Draft pattern for Appunti (Fizzy pattern)
def draft_new_appunto(appuntabile: nil)
  appunti.find_or_initialize_by(status: "drafted").tap do |appunto|
    appunto.appuntabile = appuntabile if appuntabile
    appunto.update!(created_at: Time.current, updated_at: Time.current)
  end
end
```

**Step 2: Remove related tests**

In `test/models/user_test.rb`, rimuovere i test `draft_new_appunto creates new draft if none exists` e `draft_new_appunto returns existing draft if one exists`.

**Step 3: Verify no other references remain**

Run: `grep -r "draft_new_appunto" app/ test/`
Expected: nessun risultato

**Step 4: Run all tests**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/user.rb test/models/user_test.rb
git commit -m "cleanup: remove User#draft_new_appunto, replaced by Appunti::AppuntoCreator"
```

---

### Task 7: Verifica finale end-to-end

**Step 1: Run full test suite**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS, nessuna regressione

**Step 2: Verify grep cleanup**

Run: `grep -r "draft_new_appunto" app/ test/ --include="*.rb"`
Expected: nessun risultato

Run: `grep -r "find_or_create_persona\|create_appunto.*persona.*scuola" app/controllers/ --include="*.rb"`
Expected: nessun risultato (logica ora nel creator)

**Step 3: Commit finale se serve**

Se ci sono fix residui, committare con messaggio appropriato.
