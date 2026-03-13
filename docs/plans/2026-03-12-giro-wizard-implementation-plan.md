# Giro Wizard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a full-screen wizard for guided giro creation with automatic tappa generation based on giro type (kit adozioni, collane, ritiro collane, consegne, visite).

**Architecture:** Multi-step wizard rendered as a full page (not dialog). Each step is a Turbo Frame that swaps content. Data accumulates via hidden fields across steps. On final submit, controller creates Giro + Tappe in a single transaction.

**Tech Stack:** Rails 8.1, Turbo Frames, Stimulus, PostgreSQL (UUID tables)

---

### Task 1: Migration — Add `tipo_giro` and `collana_id` to Giri

**Files:**
- Create: `db/migrate/XXXXXX_add_tipo_giro_and_collana_to_giri.rb`
- Modify: `app/models/giro.rb`

**Step 1: Generate migration**

```bash
docker exec prova-app-1 bin/rails generate migration AddTipoGiroAndCollanaToGiri tipo_giro:string collana_id:uuid
```

**Step 2: Edit migration to add index**

```ruby
class AddTipoGiroAndCollanaToGiri < ActiveRecord::Migration[8.1]
  def change
    add_column :giri, :tipo_giro, :string
    add_column :giri, :collana_id, :uuid
    add_index :giri, :collana_id
  end
end
```

**Step 3: Run migration**

```bash
docker exec prova-app-1 bin/rails db:migrate
```

**Step 4: Update Giro model**

Add to `app/models/giro.rb`:

```ruby
belongs_to :collana, optional: true

TIPI_GIRO = %w[kit_adozioni collane ritiro_collane consegne visite].freeze
validates :tipo_giro, inclusion: { in: TIPI_GIRO }, allow_nil: true
```

**Step 5: Commit**

```bash
git add db/migrate/*add_tipo_giro* app/models/giro.rb db/schema.rb
git commit -m "feat: add tipo_giro and collana_id to giri"
```

---

### Task 2: Scartata model and Scartabile concern

**Files:**
- Create: `db/migrate/XXXXXX_create_scartate.rb`
- Create: `app/models/scartata.rb`
- Create: `app/models/concerns/scartabile.rb`
- Modify: `app/models/scuola.rb`

**Step 1: Generate migration**

```bash
docker exec prova-app-1 bin/rails generate migration CreateScartate
```

**Step 2: Write migration**

```ruby
class CreateScartate < ActiveRecord::Migration[8.1]
  def change
    create_table :scartate, id: :uuid do |t|
      t.references :scuola, type: :uuid, null: false
      t.references :user, null: false
      t.references :account, type: :uuid, null: false
      t.timestamps
    end
    add_index :scartate, [:scuola_id, :user_id], unique: true
  end
end
```

**Step 3: Run migration**

```bash
docker exec prova-app-1 bin/rails db:migrate
```

**Step 4: Create Scartata model**

Create `app/models/scartata.rb`:

```ruby
class Scartata < ApplicationRecord
  include AccountScoped

  belongs_to :scuola
  belongs_to :user, default: -> { Current.user }

  validates :scuola_id, uniqueness: { scope: :user_id }
end
```

**Step 5: Create Scartabile concern**

Create `app/models/concerns/scartabile.rb`:

```ruby
module Scartabile
  extend ActiveSupport::Concern

  included do
    has_one :scartata, dependent: :destroy

    scope :non_scartate, -> { where.missing(:scartata) }
    scope :scartate, -> { joins(:scartata) }
  end

  def scartata?
    scartata.present?
  end
end
```

**Step 6: Include concern in Scuola**

Add to `app/models/scuola.rb` after `include Saldabile`:

```ruby
include Scartabile
```

**Step 7: Commit**

```bash
git add db/migrate/*create_scartate* app/models/scartata.rb app/models/concerns/scartabile.rb app/models/scuola.rb db/schema.rb
git commit -m "feat: add Scartata model and Scartabile concern on Scuola"
```

---

### Task 3: Routes for wizard

**Files:**
- Modify: `config/routes.rb`

**Step 1: Add wizard routes**

Inside the existing `resources :giri` block in `config/routes.rb` (around line 329), add the wizard namespace:

```ruby
resources :giri do
  member do
    get 'planner'
    get 'copia'
  end

  # Wizard
  collection do
    get  'wizard',            to: 'giri/wizard#new',       as: 'wizard_giri'
    get  'wizard/scuole',     to: 'giri/wizard#scuole',    as: 'wizard_giri_scuole'
    get  'wizard/riepilogo',  to: 'giri/wizard#riepilogo', as: 'wizard_giri_riepilogo'
    post 'wizard',            to: 'giri/wizard#create',    as: 'create_wizard_giro'
  end

  # existing tappa generation routes...
  get  'genera_tappe', to: 'giri/tappe#new', as: 'genera_tappe'
  post 'genera_tappe', to: 'giri/tappe#create'
  post 'copia_tappe', to: 'giri/tappe#copy', as: 'copia_tappe'
  delete 'svuota_tappe', to: 'giri/tappe#destroy_all', as: 'svuota_tappe'
end
```

**Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add wizard routes for giri"
```

---

### Task 4: Wizard Controller

**Files:**
- Create: `app/controllers/giri/wizard_controller.rb`

**Step 1: Create the controller**

Create `app/controllers/giri/wizard_controller.rb`:

```ruby
module Giri
  class WizardController < ApplicationController
    before_action :authenticate_user!

    # GET /giri/wizard — Step 1 (tipo) + Step 2 (info)
    def new
      @collane = Current.user.collane.ordered
    end

    # GET /giri/wizard/scuole — Step 3 (scuole)
    def scuole
      @tipo_giro = params[:tipo_giro]
      @titolo = params[:titolo]
      @colore = params[:color]
      @collana_id = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il = params[:finito_il]

      @scuole = scuole_per_tipo(@tipo_giro, @collana_id)
      @conteggio = @scuole.size

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end

    # GET /giri/wizard/riepilogo — Step 4 (conferma)
    def riepilogo
      @tipo_giro = params[:tipo_giro]
      @titolo = params[:titolo]
      @colore = params[:color]
      @collana_id = params[:collana_id]
      @iniziato_il = params[:iniziato_il]
      @finito_il = params[:finito_il]
      @school_ids = Array(params[:school_ids])
      @collana = Collana.find_by(id: @collana_id) if @collana_id.present?
      @conteggio = @school_ids.size
    end

    # POST /giri/wizard — Crea giro + tappe
    def create
      tipo_giro = params[:tipo_giro]
      school_ids = Array(params[:school_ids])

      giro = current_user.giri.new(
        titolo: params[:titolo],
        tipo_giro: tipo_giro,
        color: params[:color].presence || "var(--color-card-default)",
        collana_id: params[:collana_id].presence,
        iniziato_il: params[:iniziato_il].presence,
        finito_il: params[:finito_il].presence,
        account: Current.account
      )

      ActiveRecord::Base.transaction do
        giro.save!

        school_ids.each do |school_id|
          tappa = current_user.tappe.create!(
            tappable_type: "Scuola",
            tappable_id: school_id,
            account: Current.account,
            data_tappa: nil
          )
          tappa.tappa_giri.create!(giro: giro)
        end
      end

      redirect_to giro_path(giro), notice: "Giro creato con #{school_ids.size} tappe."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to wizard_giri_path, alert: e.message
    end

    private

    def scuole_per_tipo(tipo, collana_id = nil)
      base = plessi_scope

      case tipo
      when "kit_adozioni"
        base.joins(classi: :adozioni)
            .where(adozioni: { mia: true })
            .distinct
      when "collane"
        base.non_scartate
      when "ritiro_collane"
        base.joins(:bolle_visione)
            .where(bolle_visione: { collana_id: collana_id, user_id: current_user.id })
            .distinct
      when "consegne", "visite"
        base.non_scartate
      else
        base
      end.order(:posizione)
    end

    # Solo plessi e scuole autonome, mai le direzioni
    def plessi_scope
      Current.scuole.where.not(
        id: Scuola.unscoped.select(:direzione_id).where.not(direzione_id: nil)
      )
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/controllers/giri/wizard_controller.rb
git commit -m "feat: add Giri::WizardController with step logic"
```

---

### Task 5: Wizard views — Layout and Step 1+2

**Files:**
- Create: `app/views/giri/wizard/new.html.erb`

**Step 1: Create the wizard view**

Create `app/views/giri/wizard/new.html.erb`:

```erb
<% content_for :hide_footer, true %>
<% @page_title = "Nuovo giro" %>

<%= form_tag create_wizard_giro_path, method: :post, id: "wizard-form",
    data: { controller: "wizard", wizard_step_value: "tipo" } do %>

  <div class="wizard">
    <!-- Sidebar -->
    <aside class="wizard__sidebar">
      <h2 class="txt-large txt-bold padding-block-end">Nuovo giro</h2>
      <ol class="wizard__steps">
        <li class="wizard__step" data-wizard-target="stepIndicator" data-step="tipo">
          <span class="wizard__step-number">1</span> Tipo giro
        </li>
        <li class="wizard__step" data-wizard-target="stepIndicator" data-step="info">
          <span class="wizard__step-number">2</span> Dettagli
        </li>
        <li class="wizard__step" data-wizard-target="stepIndicator" data-step="scuole">
          <span class="wizard__step-number">3</span> Scuole
        </li>
        <li class="wizard__step" data-wizard-target="stepIndicator" data-step="riepilogo">
          <span class="wizard__step-number">4</span> Riepilogo
        </li>
      </ol>
      <div class="margin-block-start-auto padding-block-start">
        <%= link_to "Annulla", giri_path, class: "btn btn--plain" %>
      </div>
    </aside>

    <!-- Main content -->
    <div class="wizard__content">
      <!-- Step 1: Tipo giro -->
      <div class="wizard__panel" data-wizard-target="panel" data-step="tipo">
        <h3 class="txt-large margin-block-end">Che tipo di giro vuoi creare?</h3>
        <div class="wizard__grid">
          <% [
            ["kit_adozioni", "Kit adozioni", "Consegna kit nelle scuole con le tue adozioni", "book"],
            ["collane", "Consegna collane", "Porta le collane in visione nelle scuole", "stack"],
            ["ritiro_collane", "Ritiro collane", "Ritira le collane date in visione", "return"],
            ["consegne", "Consegne", "Consegna documenti e DDT", "truck"],
            ["visite", "Visite", "Giro di visite commerciali", "route"]
          ].each do |value, label, desc, icon_name| %>
            <label class="wizard__card" data-action="click->wizard#selectTipo">
              <%= radio_button_tag :tipo_giro, value, false,
                  data: { wizard_target: "tipoInput" }, class: "for-screen-reader" %>
              <div class="wizard__card-icon"><%= icon_tag icon_name %></div>
              <div class="wizard__card-label txt-bold"><%= label %></div>
              <div class="wizard__card-desc txt-small txt-subtle"><%= desc %></div>
            </label>
          <% end %>
        </div>
      </div>

      <!-- Step 2: Info giro -->
      <div class="wizard__panel" data-wizard-target="panel" data-step="info" hidden>
        <h3 class="txt-large margin-block-end">Dettagli del giro</h3>
        <div class="flex flex-column gap">
          <div>
            <label class="txt-small txt-bold">Titolo</label>
            <%= text_field_tag :titolo, "", class: "input", data: { wizard_target: "titoloInput" } %>
          </div>

          <div data-wizard-target="collanaField" hidden>
            <label class="txt-small txt-bold">Collana</label>
            <%= select_tag :collana_id,
                options_from_collection_for_select(@collane, :id, :nome),
                include_blank: "Seleziona collana...",
                class: "input" %>
          </div>

          <div class="flex gap">
            <div class="flex-item-grow">
              <label class="txt-small txt-bold">Data inizio</label>
              <%= date_field_tag :iniziato_il, nil, class: "input" %>
            </div>
            <div class="flex-item-grow">
              <label class="txt-small txt-bold">Data fine</label>
              <%= date_field_tag :finito_il, nil, class: "input" %>
            </div>
          </div>

          <div>
            <label class="txt-small txt-bold margin-block-end-half">Colore</label>
            <div class="flex gap-half flex-wrap">
              <% Color::COLORS.each do |color| %>
                <label class="btn btn--icon" style="--btn-background: <%= color.value %>;">
                  <%= radio_button_tag :color, color.value, color.value == "var(--color-card-default)", class: "for-screen-reader" %>
                  <%= icon_tag "check", class: "icon--small" %>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Step 3: Scuole (loaded via Turbo Frame) -->
      <div class="wizard__panel" data-wizard-target="panel" data-step="scuole" hidden>
        <%= turbo_frame_tag "wizard_scuole", src: nil, loading: :lazy do %>
          <p class="txt-subtle">Caricamento scuole...</p>
        <% end %>
      </div>

      <!-- Step 4: Riepilogo (loaded via Turbo Frame) -->
      <div class="wizard__panel" data-wizard-target="panel" data-step="riepilogo" hidden>
        <%= turbo_frame_tag "wizard_riepilogo" do %>
          <p class="txt-subtle">Caricamento riepilogo...</p>
        <% end %>
      </div>

      <!-- Footer navigation -->
      <div class="wizard__footer">
        <button type="button" class="btn btn--plain" data-action="wizard#prevStep"
                data-wizard-target="prevBtn" hidden>
          Indietro
        </button>
        <div class="flex-item-grow"></div>
        <button type="button" class="btn btn--primary" data-action="wizard#nextStep"
                data-wizard-target="nextBtn">
          Avanti
        </button>
        <button type="submit" class="btn btn--primary" data-wizard-target="submitBtn" hidden>
          Crea giro
        </button>
      </div>
    </div>
  </div>
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/giri/wizard/new.html.erb
git commit -m "feat: wizard view with step 1 (tipo) and step 2 (info)"
```

---

### Task 6: Wizard views — Step 3 (scuole) and Step 4 (riepilogo)

**Files:**
- Create: `app/views/giri/wizard/scuole.html.erb`
- Create: `app/views/giri/wizard/riepilogo.html.erb`

**Step 1: Create scuole step view**

Create `app/views/giri/wizard/scuole.html.erb`:

```erb
<%= turbo_frame_tag "wizard_scuole" do %>
  <h3 class="txt-large margin-block-end">
    Scuole selezionate
    <span class="badge" data-wizard-target="schoolCount"><%= @conteggio %></span>
  </h3>

  <div class="flex gap-half margin-block-end">
    <button type="button" class="btn btn--small btn--plain" data-action="wizard#selectAllSchools">
      Seleziona tutte
    </button>
    <button type="button" class="btn btn--small btn--plain" data-action="wizard#deselectAllSchools">
      Deseleziona tutte
    </button>
  </div>

  <div class="wizard__school-list" data-wizard-target="schoolList">
    <% @scuole.group_by(&:provincia).each do |provincia, scuole_prov| %>
      <details open>
        <summary class="txt-bold txt-small padding-block-half">
          <%= provincia %> (<%= scuole_prov.size %>)
        </summary>
        <div class="flex flex-column gap-quarter padding-inline-start">
          <% scuole_prov.each do |scuola| %>
            <label class="flex align-center gap-half padding-block-quarter">
              <%= check_box_tag "school_ids[]", scuola.id, true,
                  data: { wizard_target: "schoolCheckbox" } %>
              <span class="txt-small"><%= scuola.denominazione %></span>
              <span class="txt-xx-small txt-subtle"><%= scuola.comune %></span>
            </label>
          <% end %>
        </div>
      </details>
    <% end %>
  </div>
<% end %>
```

**Step 2: Create riepilogo step view**

Create `app/views/giri/wizard/riepilogo.html.erb`:

```erb
<%= turbo_frame_tag "wizard_riepilogo" do %>
  <h3 class="txt-large margin-block-end">Riepilogo</h3>

  <div class="card padding">
    <dl class="flex flex-column gap-half">
      <div class="flex gap">
        <dt class="txt-bold txt-small" style="min-inline-size: 8rem;">Tipo</dt>
        <dd class="txt-small"><%= t("giri.tipi.#{@tipo_giro}", default: @tipo_giro.humanize) %></dd>
      </div>
      <div class="flex gap">
        <dt class="txt-bold txt-small" style="min-inline-size: 8rem;">Titolo</dt>
        <dd class="txt-small"><%= @titolo %></dd>
      </div>
      <% if @collana.present? %>
        <div class="flex gap">
          <dt class="txt-bold txt-small" style="min-inline-size: 8rem;">Collana</dt>
          <dd class="txt-small"><%= @collana.nome %></dd>
        </div>
      <% end %>
      <div class="flex gap">
        <dt class="txt-bold txt-small" style="min-inline-size: 8rem;">Scuole</dt>
        <dd class="txt-small"><%= @conteggio %> scuole</dd>
      </div>
    </dl>
  </div>

  <% @school_ids.each do |id| %>
    <%= hidden_field_tag "school_ids[]", id %>
  <% end %>
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/giri/wizard/scuole.html.erb app/views/giri/wizard/riepilogo.html.erb
git commit -m "feat: wizard step 3 (scuole) and step 4 (riepilogo)"
```

---

### Task 7: Stimulus wizard controller

**Files:**
- Create: `app/javascript/controllers/wizard_controller.js`

**Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/wizard_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepIndicator", "tipoInput", "titoloInput",
    "collanaField", "prevBtn", "nextBtn", "submitBtn",
    "schoolCheckbox", "schoolCount", "schoolList"
  ]
  static values = { step: String }

  // Step order
  steps = ["tipo", "info", "scuole", "riepilogo"]

  connect() {
    this.showStep(this.stepValue || "tipo")
  }

  selectTipo(e) {
    const card = e.currentTarget
    const input = card.querySelector("input[type=radio]")
    if (!input) return

    // Visual selection
    this.element.querySelectorAll(".wizard__card").forEach(c => c.classList.remove("wizard__card--selected"))
    card.classList.add("wizard__card--selected")

    // Precompile titolo
    const labels = {
      kit_adozioni: "Kit Adozioni",
      collane: "Collane",
      ritiro_collane: "Ritiro Collane",
      consegne: "Consegne",
      visite: "Visite"
    }
    if (this.hasTitoloInputTarget) {
      this.titoloInputTarget.value = labels[input.value] || ""
    }

    // Show/hide collana field
    if (this.hasCollanaFieldTarget) {
      const needsCollana = ["collane", "ritiro_collane"].includes(input.value)
      this.collanaFieldTarget.hidden = !needsCollana
    }
  }

  nextStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex < 0) return

    // Validation
    if (this.stepValue === "tipo") {
      const selected = this.tipoInputTargets.find(i => i.checked)
      if (!selected) return
    }

    const nextStep = this.steps[currentIndex + 1]
    if (!nextStep) return

    // Load scuole via Turbo Frame when entering step 3
    if (nextStep === "scuole") {
      this.loadScuole()
    }

    this.showStep(nextStep)
  }

  prevStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex <= 0) return
    this.showStep(this.steps[currentIndex - 1])
  }

  showStep(step) {
    this.stepValue = step
    const index = this.steps.indexOf(step)

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.step !== step
    })

    // Update step indicators
    this.stepIndicatorTargets.forEach(indicator => {
      const stepIndex = this.steps.indexOf(indicator.dataset.step)
      indicator.classList.toggle("wizard__step--active", indicator.dataset.step === step)
      indicator.classList.toggle("wizard__step--completed", stepIndex < index)
    })

    // Show/hide nav buttons
    if (this.hasPrevBtnTarget) this.prevBtnTarget.hidden = index === 0
    if (this.hasNextBtnTarget) this.nextBtnTarget.hidden = index === this.steps.length - 1
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.hidden = index !== this.steps.length - 1
  }

  loadScuole() {
    const tipo = this.tipoInputTargets.find(i => i.checked)?.value
    if (!tipo) return

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value
    })

    const frame = this.element.querySelector("turbo-frame#wizard_scuole")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/scuole")
      frame.src = `${basePath}?${params}`
    }
  }

  selectAllSchools() {
    this.schoolCheckboxTargets.forEach(cb => cb.checked = true)
    this.updateSchoolCount()
  }

  deselectAllSchools() {
    this.schoolCheckboxTargets.forEach(cb => cb.checked = false)
    this.updateSchoolCount()
  }

  updateSchoolCount() {
    const count = this.schoolCheckboxTargets.filter(cb => cb.checked).length
    if (this.hasSchoolCountTarget) {
      this.schoolCountTarget.textContent = count
    }
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/wizard_controller.js
git commit -m "feat: Stimulus wizard controller for multi-step navigation"
```

---

### Task 8: Wizard CSS

**Files:**
- Create: `app/assets/stylesheets/modules/_wizard.css`
- Modify: `app/assets/stylesheets/application.css` (add import)

**Step 1: Create wizard CSS**

Create `app/assets/stylesheets/modules/_wizard.css`:

```css
.wizard {
  display: grid;
  grid-template-columns: 16rem 1fr;
  min-block-size: 100dvh;
}

.wizard__sidebar {
  display: flex;
  flex-direction: column;
  padding: var(--space);
  background: var(--color-surface-alt);
  border-inline-end: 1px solid var(--color-border);
}

.wizard__steps {
  list-style: none;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: var(--space-half);
}

.wizard__step {
  display: flex;
  align-items: center;
  gap: var(--space-half);
  padding: var(--space-half);
  border-radius: var(--radius);
  color: var(--color-txt-subtle);
  font-size: var(--font-size-small);
}

.wizard__step--active {
  background: var(--color-surface);
  color: var(--color-txt);
  font-weight: 600;
}

.wizard__step--completed {
  color: var(--color-positive);
}

.wizard__step-number {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  inline-size: 1.5rem;
  block-size: 1.5rem;
  border-radius: 50%;
  background: var(--color-border);
  font-size: var(--font-size-x-small);
  font-weight: 600;
}

.wizard__step--active .wizard__step-number {
  background: var(--color-accent);
  color: white;
}

.wizard__step--completed .wizard__step-number {
  background: var(--color-positive);
  color: white;
}

.wizard__content {
  display: flex;
  flex-direction: column;
  padding: var(--space-double);
  max-inline-size: 60rem;
}

.wizard__panel {
  flex: 1;
}

.wizard__footer {
  display: flex;
  align-items: center;
  gap: var(--space);
  padding-block-start: var(--space);
  border-block-start: 1px solid var(--color-border);
  margin-block-start: auto;
}

/* Step 1: Tipo cards */
.wizard__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr));
  gap: var(--space);
}

.wizard__card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-half);
  padding: var(--space);
  border: 2px solid var(--color-border);
  border-radius: var(--radius);
  cursor: pointer;
  text-align: center;
  transition: border-color 0.15s;
}

.wizard__card:hover {
  border-color: var(--color-accent);
}

.wizard__card--selected {
  border-color: var(--color-accent);
  background: var(--color-accent-subtle);
}

.wizard__card-icon {
  font-size: 2rem;
  color: var(--color-accent);
}

.wizard__card-desc {
  line-height: 1.3;
}

/* Step 3: School list */
.wizard__school-list {
  max-block-size: 60vh;
  overflow-y: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  padding: var(--space-half);
}
```

**Step 2: Add import to application.css**

Add in the modules layer section of `app/assets/stylesheets/application.css`:

```css
@import "modules/wizard";
```

**Step 3: Commit**

```bash
git add app/assets/stylesheets/modules/_wizard.css app/assets/stylesheets/application.css
git commit -m "feat: wizard CSS styles"
```

---

### Task 9: Link to wizard from giri index

**Files:**
- Modify: `app/views/giri/index.html.erb` (add wizard button)

**Step 1: Add wizard link**

Find the existing "Nuovo giro" button/link in `app/views/giri/index.html.erb` and add a wizard link next to it:

```erb
<%= link_to wizard_giri_path, class: "btn btn--primary" do %>
  <%= icon_tag "wand" %> Nuovo giro guidato
<% end %>
```

**Step 2: Commit**

```bash
git add app/views/giri/index.html.erb
git commit -m "feat: add wizard link to giri index"
```

---

### Task 10: Scartata toggle on scuola show page

**Files:**
- Create: `app/controllers/scuole/scartate_controller.rb`
- Create: `app/views/scuole/scartate/create.turbo_stream.erb`
- Create: `app/views/scuole/scartate/destroy.turbo_stream.erb`
- Modify: `config/routes.rb` (add nested route)

**Step 1: Add route**

In `config/routes.rb`, inside the `resources :scuole` block, add:

```ruby
resource :scartata, only: [:create, :destroy], controller: "scuole/scartate"
```

**Step 2: Create controller**

Create `app/controllers/scuole/scartate_controller.rb`:

```ruby
module Scuole
  class ScartateController < ApplicationController
    before_action :set_scuola

    def create
      @scuola.create_scartata!(user: Current.user, account: Current.account)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    def destroy
      @scuola.scartata&.destroy
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to scuola_path(@scuola) }
      end
    end

    private

    def set_scuola
      @scuola = Current.account.scuole.find(params[:scuola_id])
    end
  end
end
```

**Step 3: Create turbo_stream views**

Create `app/views/scuole/scartate/create.turbo_stream.erb`:

```erb
<%= turbo_stream.replace dom_id(@scuola, :scartata) do %>
  <%= render "scuole/scartata_toggle", scuola: @scuola.reload %>
<% end %>
```

Create `app/views/scuole/scartate/destroy.turbo_stream.erb`:

```erb
<%= turbo_stream.replace dom_id(@scuola, :scartata) do %>
  <%= render "scuole/scartata_toggle", scuola: @scuola.reload %>
<% end %>
```

**Step 4: Create toggle partial**

Create `app/views/scuole/_scartata_toggle.html.erb`:

```erb
<%# locals: (scuola:) -%>
<div id="<%= dom_id(scuola, :scartata) %>">
  <% if scuola.scartata? %>
    <%= button_to scuola_scartata_path(scuola), method: :delete, class: "btn btn--small btn--warning" do %>
      <%= icon_tag "close" %> Scartata
    <% end %>
  <% else %>
    <%= button_to scuola_scartata_path(scuola), method: :post, class: "btn btn--small btn--plain" do %>
      Scarta
    <% end %>
  <% end %>
</div>
```

**Step 5: Commit**

```bash
git add app/controllers/scuole/scartate_controller.rb app/views/scuole/scartate/ app/views/scuole/_scartata_toggle.html.erb config/routes.rb
git commit -m "feat: scartata toggle CRUD on scuola"
```

---

### Task 11: Integration test

**Files:**
- Create: `test/controllers/giri/wizard_controller_test.rb`

**Step 1: Create test**

Create `test/controllers/giri/wizard_controller_test.rb`:

```ruby
require "test_helper"

class Giri::WizardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "GET wizard shows step 1" do
    get wizard_giri_path
    assert_response :success
    assert_select ".wizard__card", minimum: 5
  end

  test "GET wizard/scuole returns scuole for collane tipo" do
    get wizard_giri_scuole_path(tipo_giro: "collane")
    assert_response :success
  end

  test "POST wizard creates giro with tappe" do
    scuola = Current.account.scuole.first

    assert_difference ["Giro.count", "Tappa.count"] do
      post create_wizard_giro_path, params: {
        tipo_giro: "visite",
        titolo: "Test Visite",
        school_ids: [scuola.id]
      }
    end

    giro = Giro.last
    assert_equal "visite", giro.tipo_giro
    assert_equal "Test Visite", giro.titolo
    assert_equal 1, giro.tappe.count
    assert_redirected_to giro_path(giro)
  end
end
```

**Step 2: Run test**

```bash
docker exec prova-app-1 bin/rails test test/controllers/giri/wizard_controller_test.rb
```

**Step 3: Commit**

```bash
git add test/controllers/giri/wizard_controller_test.rb
git commit -m "test: wizard controller integration tests"
```

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | Migration: tipo_giro + collana_id su Giro | migration, giro.rb |
| 2 | Scartata model + Scartabile concern | migration, model, concern, scuola.rb |
| 3 | Routes wizard | routes.rb |
| 4 | WizardController | controller |
| 5 | Views: step 1 (tipo) + step 2 (info) | new.html.erb |
| 6 | Views: step 3 (scuole) + step 4 (riepilogo) | scuole.html.erb, riepilogo.html.erb |
| 7 | Stimulus wizard controller | wizard_controller.js |
| 8 | CSS wizard | _wizard.css, application.css |
| 9 | Link wizard da giri index | index.html.erb |
| 10 | Scartata toggle su scuola | controller, views, routes |
| 11 | Test integrazione | test file |
