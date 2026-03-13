# Disponibilità Scuola Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a flexible Disponibilita model to track school availability (schedules, closures, patron saints, polling stations, meetings) with a UI section in the scuola show page.

**Architecture:** Single polymorphic model `Disponibilita` with `tipo` enum. `HasDisponibilita` concern on Scuola. Nested CRUD controller with Turbo Stream responses. UI rendered as a section in the scuola show page below prossime visite.

**Tech Stack:** Rails 8.1, PostgreSQL (UUID), Turbo Streams, Stimulus

---

### Task 1: Migration — Create disponibilita table

**Files:**
- Create: `db/migrate/XXXXXX_create_disponibilita.rb`

**Step 1: Generate migration**

```bash
docker exec prova-app-1 bin/rails generate migration CreateDisponibilita
```

**Step 2: Write migration**

```ruby
class CreateDisponibilita < ActiveRecord::Migration[8.1]
  def change
    create_table :disponibilita, id: :uuid do |t|
      t.references :scuola, type: :uuid, null: false
      t.references :account, type: :uuid, null: false
      t.references :user, null: true
      t.string :tipo, null: false
      t.integer :giorno_settimana
      t.date :data
      t.time :ora_inizio
      t.time :ora_fine
      t.string :titolo
      t.boolean :ricorrente, default: false
      t.timestamps
    end

    add_index :disponibilita, [:scuola_id, :tipo]
    add_index :disponibilita, [:scuola_id, :tipo, :giorno_settimana],
              name: "idx_disponibilita_scuola_tipo_giorno"
  end
end
```

**Step 3: Run migration**

```bash
docker exec prova-app-1 bin/rails db:migrate
```

**Step 4: Commit**

```bash
git add db/migrate/*create_disponibilita* db/schema.rb
git commit -m "feat: create disponibilita table"
```

---

### Task 2: Disponibilita model

**Files:**
- Create: `app/models/disponibilita.rb`

**Step 1: Create model**

Create `app/models/disponibilita.rb`:

```ruby
class Disponibilita < ApplicationRecord
  include AccountScoped

  belongs_to :scuola
  belongs_to :user, optional: true

  TIPI = %w[orario chiusura patrono seggio riunione nota].freeze
  GIORNI = { 1 => "Lunedì", 2 => "Martedì", 3 => "Mercoledì",
             4 => "Giovedì", 5 => "Venerdì", 6 => "Sabato", 0 => "Domenica" }.freeze

  validates :tipo, presence: true, inclusion: { in: TIPI }
  validates :giorno_settimana, presence: true, if: -> { tipo.in?(%w[orario riunione]) }
  validates :data, presence: true, if: -> { tipo.in?(%w[chiusura patrono]) }

  before_validation :set_ricorrente_for_patrono

  scope :orari, -> { where(tipo: "orario").order(:giorno_settimana, :ora_inizio) }
  scope :chiusure, -> { where(tipo: "chiusura").order(:data) }
  scope :chiusure_future, -> { chiusure.where("data >= ?", Date.today) }
  scope :patroni, -> { where(tipo: "patrono") }
  scope :seggi, -> { where(tipo: "seggio") }
  scope :riunioni, -> { where(tipo: "riunione").order(:giorno_settimana, :ora_inizio) }
  scope :note_utente, -> { where(tipo: "nota") }
  scope :della_scuola, -> { where(user_id: nil) }
  scope :dell_utente, ->(user) { where(user_id: user.id) }

  def orario_label
    return unless ora_inizio && ora_fine
    "#{ora_inizio.strftime('%H:%M')}-#{ora_fine.strftime('%H:%M')}"
  end

  def giorno_label
    GIORNI[giorno_settimana]
  end

  private

  def set_ricorrente_for_patrono
    self.ricorrente = true if tipo == "patrono"
  end
end
```

**Step 2: Commit**

```bash
git add app/models/disponibilita.rb
git commit -m "feat: add Disponibilita model with validations and scopes"
```

---

### Task 3: HasDisponibilita concern

**Files:**
- Create: `app/models/concerns/has_disponibilita.rb`
- Modify: `app/models/scuola.rb`

**Step 1: Create concern**

Create `app/models/concerns/has_disponibilita.rb`:

```ruby
module HasDisponibilita
  extend ActiveSupport::Concern

  included do
    has_many :disponibilita, dependent: :destroy
    has_many :disponibilita_scuola, -> { where(user_id: nil) },
             class_name: "Disponibilita"
  end

  def orario_del_giorno(giorno_settimana)
    disponibilita.orari.where(giorno_settimana: giorno_settimana)
  end

  def chiusa_il?(data)
    return true if disponibilita.where(tipo: "chiusura", data: data).exists?
    return true if disponibilita.where(tipo: "patrono", ricorrente: true)
                                .where("EXTRACT(MONTH FROM data) = ? AND EXTRACT(DAY FROM data) = ?",
                                       data.month, data.day).exists?
    false
  end

  def sede_seggio?
    disponibilita.seggi.exists?
  end

  def riunioni_del_giorno(giorno_settimana)
    disponibilita.riunioni.where(giorno_settimana: giorno_settimana)
  end

  def indisponibilita_per(data)
    wday = data.wday
    disponibilita.where(tipo: "chiusura", data: data)
      .or(disponibilita.where(tipo: "patrono", ricorrente: true)
          .where("EXTRACT(MONTH FROM data) = ? AND EXTRACT(DAY FROM data) = ?",
                 data.month, data.day))
      .or(disponibilita.where(tipo: "riunione", giorno_settimana: wday))
  end

  def ha_orario?
    disponibilita.orari.exists?
  end
end
```

**Step 2: Add concern to Scuola**

In `app/models/scuola.rb`, after `include Saldabile` (around line 56), add:

```ruby
include HasDisponibilita
```

**Step 3: Commit**

```bash
git add app/models/concerns/has_disponibilita.rb app/models/scuola.rb
git commit -m "feat: add HasDisponibilita concern to Scuola"
```

---

### Task 4: Routes

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add nested route**

In `config/routes.rb`, inside the `resources :scuole` block (look for `scope module: :scuoles`), add:

```ruby
resources :disponibilita, only: [:create, :destroy], controller: "scuole/disponibilita"
```

**Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add disponibilita nested routes under scuole"
```

---

### Task 5: Controller

**Files:**
- Create: `app/controllers/scuole/disponibilita_controller.rb`

**Step 1: Create controller**

Create `app/controllers/scuole/disponibilita_controller.rb`:

```ruby
module Scuole
  class DisponibilitaController < ApplicationController
    before_action :authenticate_user!
    before_action :set_scuola

    def create
      @disponibilita = @scuola.disponibilita.new(disponibilita_params)
      @disponibilita.account = Current.account
      # Note personali hanno user_id
      @disponibilita.user = Current.user if @disponibilita.tipo == "nota"

      if @disponibilita.save
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@scuola, :disponibilita),
              partial: "scuole/container/disponibilita",
              locals: { scuola: @scuola.reload }
            )
          end
          format.html { redirect_to scuola_path(@scuola) }
        end
      else
        redirect_to scuola_path(@scuola), alert: @disponibilita.errors.full_messages.join(", ")
      end
    end

    def destroy
      @disponibilita = @scuola.disponibilita.find(params[:id])
      @disponibilita.destroy

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            ActionView::RecordIdentifier.dom_id(@scuola, :disponibilita),
            partial: "scuole/container/disponibilita",
            locals: { scuola: @scuola.reload }
          )
        end
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end

    def disponibilita_params
      params.require(:disponibilita).permit(
        :tipo, :giorno_settimana, :data, :ora_inizio, :ora_fine, :titolo, :ricorrente
      )
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/controllers/scuole/disponibilita_controller.rb
git commit -m "feat: add Scuole::DisponibilitaController with create/destroy"
```

---

### Task 6: View — Disponibilita section partial

**Files:**
- Create: `app/views/scuole/container/_disponibilita.html.erb`
- Modify: `app/views/scuole/_container.html.erb`

**Step 1: Create the partial**

Create `app/views/scuole/container/_disponibilita.html.erb`:

```erb
<%# locals: (scuola:) -%>
<div id="<%= dom_id(scuola, :disponibilita) %>" class="margin-block-start">
  <div class="flex align-center justify-space-between margin-block-end-half">
    <h3 class="divider divider--fade txt-medium font-weight-black margin-none">Disponibilità</h3>
    <button type="button" class="btn btn--small btn--plain"
            data-controller="toggle" data-action="toggle#toggle"
            data-toggle-target-value="<%= dom_id(scuola, :disponibilita_form) %>">
      <%= icon_tag "add" %>
    </button>
  </div>

  <%# Form aggiunta (nascosto) %>
  <div id="<%= dom_id(scuola, :disponibilita_form) %>" hidden class="margin-block-end">
    <%= render "scuole/container/disponibilita_form", scuola: scuola %>
  </div>

  <%# Orario settimanale %>
  <% orari = scuola.disponibilita.orari %>
  <% riunioni = scuola.disponibilita.riunioni %>
  <% if orari.any? %>
    <div class="margin-block-end">
      <h4 class="txt-small txt-bold txt-subtle margin-block-end-quarter">Orario</h4>
      <div class="flex flex-column gap-quarter">
        <% (1..5).each do |wday| %>
          <% orario_giorno = orari.select { |o| o.giorno_settimana == wday } %>
          <% riunione_giorno = riunioni.select { |r| r.giorno_settimana == wday } %>
          <% next unless orario_giorno.any? %>
          <div class="flex align-center gap-half txt-small">
            <span class="txt-bold" style="min-inline-size: 3rem;"><%= Disponibilita::GIORNI[wday]&.first(3) %></span>
            <span><%= orario_giorno.map(&:orario_label).join(", ") %></span>
            <% if riunione_giorno.any? %>
              <span class="txt-subtle txt-xx-small">
                — <%= riunione_giorno.map { |r| "#{r.titolo || 'Riunione'} #{r.orario_label}" }.join(", ") %>
              </span>
            <% end %>
            <% (orario_giorno + riunione_giorno).each do |d| %>
              <%= button_to scuola_disponibilitum_path(scuola, d), method: :delete,
                  class: "btn btn--icon btn--xx-small btn--plain", data: { turbo_confirm: "Eliminare?" } do %>
                <%= icon_tag "close", class: "icon--xx-small" %>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Info fisse: seggio e patrono %>
  <% seggi = scuola.disponibilita.seggi %>
  <% patroni = scuola.disponibilita.patroni %>
  <% if seggi.any? || patroni.any? %>
    <div class="flex flex-wrap gap-half margin-block-end">
      <% seggi.each do |s| %>
        <span class="badge badge--warning flex align-center gap-quarter">
          Sede di seggio
          <%= button_to scuola_disponibilitum_path(scuola, s), method: :delete,
              class: "btn btn--icon btn--xx-small btn--plain" do %>
            <%= icon_tag "close", class: "icon--xx-small" %>
          <% end %>
        </span>
      <% end %>
      <% patroni.each do |p| %>
        <span class="badge flex align-center gap-quarter">
          <%= p.titolo %> (<%= p.data&.strftime("%-d %b") %>)
          <%= button_to scuola_disponibilitum_path(scuola, p), method: :delete,
              class: "btn btn--icon btn--xx-small btn--plain" do %>
            <%= icon_tag "close", class: "icon--xx-small" %>
          <% end %>
        </span>
      <% end %>
    </div>
  <% end %>

  <%# Chiusure future %>
  <% chiusure = scuola.disponibilita.chiusure_future %>
  <% if chiusure.any? %>
    <div class="margin-block-end">
      <h4 class="txt-small txt-bold txt-subtle margin-block-end-quarter">Chiusure</h4>
      <div class="flex flex-column gap-quarter">
        <% chiusure.each do |c| %>
          <div class="flex align-center gap-half txt-small">
            <span><%= l c.data, format: :short %></span>
            <span class="txt-subtle"><%= c.titolo %></span>
            <%= button_to scuola_disponibilitum_path(scuola, c), method: :delete,
                class: "btn btn--icon btn--xx-small btn--plain" do %>
              <%= icon_tag "close", class: "icon--xx-small" %>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>

  <%# Messaggio vuoto %>
  <% if orari.empty? && seggi.empty? && patroni.empty? && chiusure.empty? && riunioni.empty? %>
    <p class="txt-small txt-subtle">Nessuna disponibilità configurata.</p>
  <% end %>
</div>
```

**Step 2: Add to scuola container**

In `app/views/scuole/_container.html.erb`, after the "Prossime visite" section (after line 91), add:

```erb
<%= render "scuole/container/disponibilita", scuola: @scuola %>
```

**Step 3: Commit**

```bash
git add app/views/scuole/container/_disponibilita.html.erb app/views/scuole/_container.html.erb
git commit -m "feat: add disponibilita section to scuola show page"
```

---

### Task 7: View — Disponibilita form partial

**Files:**
- Create: `app/views/scuole/container/_disponibilita_form.html.erb`

**Step 1: Create the form**

Create `app/views/scuole/container/_disponibilita_form.html.erb`:

```erb
<%# locals: (scuola:) -%>
<%= form_with model: Disponibilita.new, url: scuola_disponibilita_index_path(scuola),
    class: "card padding", data: { controller: "disponibilita-form",
    action: "turbo:submit-end->disponibilita-form#reset" } do |f| %>

  <div class="form-row margin-block-end-half">
    <div class="form-field">
      <%= f.label :tipo, "Tipo", class: "label txt-small" %>
      <%= f.select :tipo,
          options_for_select([
            ["Orario lezioni", "orario"],
            ["Chiusura", "chiusura"],
            ["Santo patrono", "patrono"],
            ["Sede di seggio", "seggio"],
            ["Riunione/Programmazione", "riunione"],
            ["Nota personale", "nota"]
          ]),
          {},
          class: "input", data: { action: "change->disponibilita-form#tipoChanged",
                                  disponibilita_form_target: "tipoSelect" } %>
    </div>
  </div>

  <%# Campi giorno settimana (per orario, riunione) %>
  <div class="form-row margin-block-end-half" data-disponibilita-form-target="giornoField" hidden>
    <div class="form-field">
      <%= f.label :giorno_settimana, "Giorno", class: "label txt-small" %>
      <%= f.select :giorno_settimana,
          options_for_select([
            ["Lunedì", 1], ["Martedì", 2], ["Mercoledì", 3],
            ["Giovedì", 4], ["Venerdì", 5], ["Sabato", 6]
          ]),
          { include_blank: "Seleziona..." },
          class: "input" %>
    </div>
  </div>

  <%# Campi orario (per orario, riunione) %>
  <div class="form-row margin-block-end-half" data-disponibilita-form-target="orarioFields" hidden>
    <div class="form-field" style="--w: 10ch;">
      <%= f.label :ora_inizio, "Dalle", class: "label txt-small" %>
      <%= f.time_field :ora_inizio, class: "input" %>
    </div>
    <div class="form-field" style="--w: 10ch;">
      <%= f.label :ora_fine, "Alle", class: "label txt-small" %>
      <%= f.time_field :ora_fine, class: "input" %>
    </div>
  </div>

  <%# Campo data (per chiusura, patrono) %>
  <div class="form-row margin-block-end-half" data-disponibilita-form-target="dataField" hidden>
    <div class="form-field">
      <%= f.label :data, "Data", class: "label txt-small" %>
      <%= f.date_field :data, class: "input" %>
    </div>
  </div>

  <%# Campo titolo (per chiusura, patrono, riunione, nota) %>
  <div class="form-row margin-block-end-half" data-disponibilita-form-target="titoloField" hidden>
    <div class="form-field">
      <%= f.label :titolo, "Descrizione", class: "label txt-small" %>
      <%= f.text_field :titolo, class: "input", placeholder: "es. S. Ambrogio, Programmazione..." %>
    </div>
  </div>

  <div class="flex justify-end">
    <%= f.submit "Aggiungi", class: "btn btn--small btn--primary" %>
  </div>
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/scuole/container/_disponibilita_form.html.erb
git commit -m "feat: add disponibilita form partial with dynamic fields"
```

---

### Task 8: Stimulus controller for dynamic form

**Files:**
- Create: `app/javascript/controllers/disponibilita_form_controller.js`

**Step 1: Create Stimulus controller**

Create `app/javascript/controllers/disponibilita_form_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tipoSelect", "giornoField", "orarioFields",
    "dataField", "titoloField"
  ]

  // Which fields to show for each tipo
  static fieldMap = {
    orario:   { giorno: true,  orario: true,  data: false, titolo: false },
    chiusura: { giorno: false, orario: false, data: true,  titolo: true  },
    patrono:  { giorno: false, orario: false, data: true,  titolo: true  },
    seggio:   { giorno: false, orario: false, data: false, titolo: false },
    riunione: { giorno: true,  orario: true,  data: false, titolo: true  },
    nota:     { giorno: false, orario: false, data: true,  titolo: true  }
  }

  connect() {
    this.tipoChanged()
  }

  tipoChanged() {
    const tipo = this.tipoSelectTarget.value
    const fields = this.constructor.fieldMap[tipo] || {}

    if (this.hasGiornoFieldTarget)  this.giornoFieldTarget.hidden  = !fields.giorno
    if (this.hasOrarioFieldsTarget) this.orarioFieldsTarget.hidden = !fields.orario
    if (this.hasDataFieldTarget)    this.dataFieldTarget.hidden    = !fields.data
    if (this.hasTitoloFieldTarget)  this.titoloFieldTarget.hidden  = !fields.titolo
  }

  reset() {
    this.element.reset()
    this.tipoChanged()
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/disponibilita_form_controller.js
git commit -m "feat: Stimulus controller for disponibilita form dynamic fields"
```

---

### Task 9: Fix route naming

**Important:** Rails inflects "disponibilita" as uncountable Italian. The route helper might generate `scuola_disponibilitum_path` instead of `scuola_disponibilita_path`. Fix with inflection.

**Files:**
- Modify: `config/initializers/inflections.rb`

**Step 1: Add inflection rule**

In `config/initializers/inflections.rb`, add:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable %w[disponibilita]
end
```

**Step 2: Verify routes**

```bash
docker exec prova-app-1 bin/rails routes | grep disponibilita
```

Expected output should show `scuola_disponibilita_path` (not `disponibilitum`).

**Step 3: Update view paths if needed**

If the route helper is `scuola_disponibilita_index_path` for the collection and `scuola_disponibilita_path` for a member, update the partials accordingly. The form `url:` and the delete `button_to` paths must match what `bin/rails routes` shows.

**Step 4: Commit**

```bash
git add config/initializers/inflections.rb
git commit -m "fix: add uncountable inflection for disponibilita"
```

---

### Task 10: Test

**Files:**
- Create: `test/models/disponibilita_test.rb`

**Step 1: Create test**

Create `test/models/disponibilita_test.rb`:

```ruby
require "test_helper"

class DisponibilitaTest < ActiveSupport::TestCase
  setup do
    @scuola = scuole(:one)
  end

  test "creates orario with required fields" do
    d = @scuola.disponibilita.create!(
      tipo: "orario",
      giorno_settimana: 1,
      ora_inizio: "08:00",
      ora_fine: "13:00",
      account: @scuola.account
    )
    assert d.persisted?
    assert_equal "08:00-13:00", d.orario_label
    assert_equal "Lunedì", d.giorno_label
  end

  test "orario requires giorno_settimana" do
    d = @scuola.disponibilita.new(tipo: "orario", account: @scuola.account)
    assert_not d.valid?
    assert_includes d.errors[:giorno_settimana], "can't be blank"
  end

  test "chiusura requires data" do
    d = @scuola.disponibilita.new(tipo: "chiusura", account: @scuola.account)
    assert_not d.valid?
    assert_includes d.errors[:data], "can't be blank"
  end

  test "patrono sets ricorrente automatically" do
    d = @scuola.disponibilita.create!(
      tipo: "patrono", data: "2026-12-07",
      titolo: "S. Ambrogio", account: @scuola.account
    )
    assert d.ricorrente?
  end

  test "chiusa_il? detects closure" do
    @scuola.disponibilita.create!(
      tipo: "chiusura", data: Date.tomorrow,
      titolo: "Ponte", account: @scuola.account
    )
    assert @scuola.chiusa_il?(Date.tomorrow)
    assert_not @scuola.chiusa_il?(Date.today)
  end

  test "chiusa_il? detects recurring patrono" do
    @scuola.disponibilita.create!(
      tipo: "patrono", data: "2025-12-07",
      titolo: "S. Ambrogio", account: @scuola.account
    )
    # Should match any year on Dec 7
    assert @scuola.chiusa_il?(Date.new(2026, 12, 7))
  end

  test "sede_seggio?" do
    assert_not @scuola.sede_seggio?
    @scuola.disponibilita.create!(tipo: "seggio", account: @scuola.account)
    assert @scuola.sede_seggio?
  end
end
```

**Step 2: Run test**

```bash
docker exec prova-app-1 bin/rails test test/models/disponibilita_test.rb
```

**Step 3: Commit**

```bash
git add test/models/disponibilita_test.rb
git commit -m "test: Disponibilita model tests"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Migration: create disponibilita table | migration |
| 2 | Disponibilita model | model |
| 3 | HasDisponibilita concern + include in Scuola | concern, scuola.rb |
| 4 | Routes | routes.rb |
| 5 | Controller | controller |
| 6 | View: disponibilita section partial | partial, container |
| 7 | View: form partial | form partial |
| 8 | Stimulus: dynamic form controller | JS controller |
| 9 | Fix route naming (inflection) | inflections.rb |
| 10 | Tests | test file |
