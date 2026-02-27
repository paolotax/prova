# Saggi Promozionali — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow agents to book/deliver promotional sample books to teachers, classes, or schools, with manual inventory discharge via the existing document system.

**Architecture:** Lightweight `SaggioPromozionale` model for UX + document generation for inventory. Polymorphic destinatario (Persona/Classe/Scuola). Two entry points: persona show (single) and scuola show (batch). Combobox with smart suggestions from adoptions.

**Tech Stack:** Rails 8, Turbo Frames, Stimulus (combobox-libro), HotwireCombobox, PostgreSQL UUID

---

### Task 1: Migration + Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_saggi_promozionali.rb`
- Create: `app/models/saggio_promozionale.rb`

**Step 1: Create migration**

```ruby
class CreateSaggiPromozionali < ActiveRecord::Migration[8.1]
  def up
    create_table :saggi_promozionali, id: :uuid do |t|
      t.references :account, type: :uuid, null: false
      t.references :user, type: :bigint, null: false
      t.references :libro, type: :bigint, null: false
      t.references :scuola, type: :uuid, null: false
      t.string :destinatario_type
      t.string :destinatario_id
      t.integer :stato, default: 0, null: false
      t.integer :quantita, default: 1, null: false
      t.date :data_prenotazione
      t.date :data_consegna
      t.text :note
      t.references :documento_riga, type: :bigint

      t.timestamps
    end

    add_index :saggi_promozionali, [:scuola_id, :stato]
    add_index :saggi_promozionali, [:destinatario_type, :destinatario_id], name: "idx_saggi_promo_destinatario"
    add_index :saggi_promozionali, [:account_id, :stato]
  end

  def down
    drop_table :saggi_promozionali
  end
end
```

**Step 2: Create model**

```ruby
class SaggioPromozionale < ApplicationRecord
  include AccountScoped

  belongs_to :user
  belongs_to :libro
  belongs_to :scuola
  belongs_to :destinatario, polymorphic: true, optional: true
  belongs_to :documento_riga, optional: true

  enum :stato, { prenotato: 0, consegnato: 1 }

  validates :quantita, numericality: { greater_than: 0 }
  validates :data_prenotazione, presence: true, if: :prenotato?
  validates :data_consegna, presence: true, if: :consegnato?

  before_validation :set_defaults, on: :create

  scope :da_scaricare, -> { consegnato.where(documento_riga_id: nil) }
  scope :scaricati, -> { where.not(documento_riga_id: nil) }
  scope :per_scuola, ->(scuola) { where(scuola: scuola) }

  def scaricato?
    documento_riga_id.present?
  end

  private

  def set_defaults
    self.data_prenotazione ||= Date.current if prenotato?
    self.data_consegna ||= Date.current if consegnato?
    self.user ||= Current.user
  end
end
```

**Step 3: Run migration**

Run: `docker exec prova-app-1 bin/rails db:migrate`

**Step 4: Add associations to related models**

Modify: `app/models/scuola.rb` — add:
```ruby
has_many :saggi_promozionali, dependent: :destroy
```

Modify: `app/models/persona.rb` — add:
```ruby
has_many :saggi_promozionali, as: :destinatario, dependent: :nullify
```

Modify: `app/models/classe.rb` — add:
```ruby
has_many :saggi_promozionali, as: :destinatario, dependent: :nullify
```

Modify: `app/models/libro.rb` — add:
```ruby
has_many :saggi_promozionali, dependent: :restrict_with_error
```

**Step 5: Commit**

```bash
git add db/migrate/ app/models/saggio_promozionale.rb app/models/scuola.rb app/models/persona.rb app/models/classe.rb app/models/libro.rb
git commit -m "feat: add SaggioPromozionale model and migration"
```

---

### Task 2: Controller + Routes (Persona context)

**Files:**
- Create: `app/controllers/scuole/persone/saggi_promozionali_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Create controller**

```ruby
class Scuole::Persone::SaggiPromozionaliController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola
  before_action :set_persona
  before_action :set_saggio, only: [:update, :destroy]

  def create
    @saggio = @persona.saggi_promozionali.build(saggio_params)
    @saggio.scuola = @scuola

    if @saggio.save
      redirect_to scuola_persona_path(@scuola, @persona), notice: "Saggio aggiunto"
    else
      redirect_to scuola_persona_path(@scuola, @persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    if @saggio.update(saggio_params)
      redirect_to scuola_persona_path(@scuola, @persona)
    else
      redirect_to scuola_persona_path(@scuola, @persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio.destroy
    redirect_to scuola_persona_path(@scuola, @persona)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.friendly.find(params[:scuola_id])
  end

  def set_persona
    @persona = @scuola.persone.find(params[:persona_id])
  end

  def set_saggio
    @saggio = @persona.saggi_promozionali.find(params[:id])
  end

  def saggio_params
    params.require(:saggio_promozionale).permit(:libro_id, :quantita, :stato, :note)
  end
end
```

**Step 2: Add routes**

In `config/routes.rb`, inside `resources :scuole` > `resources :persone`:

```ruby
resources :saggi_promozionali, only: [:create, :update, :destroy], module: "scuole/persone"
```

**Step 3: Commit**

```bash
git add app/controllers/scuole/persone/saggi_promozionali_controller.rb config/routes.rb
git commit -m "feat: add saggi_promozionali controller for persona context"
```

---

### Task 3: Persona show — saggi section + inline form

**Files:**
- Create: `app/views/scuole/persone/container/_saggi.html.erb`
- Modify: persona show to include the saggi section

**Step 1: Create saggi partial for persona**

```erb
<%# locals: (persona:, scuola:) -%>

<section class="group">
  <h3 class="divider divider--fade divider--card txt-medium font-weight-black margin-block-end">
    Saggi
    <% count = persona.saggi_promozionali.per_scuola(scuola).count %>
    <% if count > 0 %>
      <span class="txt-x-small txt-subtle font-weight-normal">(<%= count %>)</span>
    <% end %>
  </h3>

  <% saggi = persona.saggi_promozionali.per_scuola(scuola).includes(:libro).order(created_at: :desc) %>
  <% if saggi.any? %>
    <dl class="dl-grid dl-grid--center txt-small">
      <% saggi.each do |saggio| %>
        <dt class="txt-x-small" style="line-height: 1.1;">
          <span class="font-weight-bold"><%= link_to saggio.libro.titolo, saggio.libro, class: "txt-link" %></span>
          <br><span class="txt-xx-small txt-subtle"><%= saggio.libro.editore&.editore %></span>
        </dt>
        <dd class="flex align-center gap-half">
          <span class="badge <%= saggio.consegnato? ? 'txt-positive' : 'txt-accent' %>">
            <%= saggio.stato %>
          </span>
          <span class="txt-xx-small txt-subtle">x<%= saggio.quantita %></span>
          <% unless saggio.scaricato? %>
            <%= button_to scuola_persona_saggio_promozionale_path(scuola, persona, saggio),
                method: :patch,
                params: { saggio_promozionale: { stato: :consegnato } },
                class: "btn btn--small txt-positive borderless",
                title: "Segna consegnato" do %>
              <%= icon_tag "check", size: "small" %>
            <% end %>
            <%= button_to scuola_persona_saggio_promozionale_path(scuola, persona, saggio),
                method: :delete,
                class: "btn btn--small txt-negative borderless",
                title: "Elimina" do %>
              <%= icon_tag "x-mark", size: "small" %>
            <% end %>
          <% end %>
        </dd>
      <% end %>
    </dl>
  <% end %>

  <%# Inline form %>
  <%= form_with model: SaggioPromozionale.new,
      url: scuola_persona_saggi_promozionali_path(scuola, persona),
      class: "flex gap-half align-end flex-wrap margin-block-start-half" do |f| %>
    <fieldset class="flex-item-grow" style="flex-basis: 200px;">
      <%= f.combobox :libro_id, libri_path(format: :json),
          placeholder: "Cerca libro...",
          class: "input full-width" %>
    </fieldset>
    <fieldset>
      <%= f.select :stato, [["Prenotato", "prenotato"], ["Consegnato", "consegnato"]],
          {}, class: "input" %>
    </fieldset>
    <fieldset style="width: 60px;">
      <%= f.number_field :quantita, value: 1, min: 1, class: "input full-width", placeholder: "Qtà" %>
    </fieldset>
    <%= f.submit "Aggiungi", class: "btn btn--primary btn--small" %>
  <% end %>
</section>
```

**Step 2: Include in persona show**

Find where persona show renders sections (after appunti) and add:
```erb
<%= render "scuole/persone/container/saggi", persona: @persona, scuola: @scuola %>
```

**Step 3: Commit**

```bash
git add app/views/scuole/persone/container/_saggi.html.erb app/views/scuole/persone/
git commit -m "feat: add saggi section to persona show with inline form"
```

---

### Task 4: Controller + Routes (Scuola context)

**Files:**
- Create: `app/controllers/scuole/saggi_promozionali_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Create scuola-level controller**

```ruby
class Scuole::SaggiPromozionaliController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  # GET — lazy loaded list of all saggi for this scuola
  def show
    @saggi = @scuola.saggi_promozionali
      .includes(:libro, :destinatario, :documento_riga)
      .order(created_at: :desc)
    @da_scaricare_count = @saggi.da_scaricare.count
  end

  # POST — batch create from scuola form
  def create
    @saggio = @scuola.saggi_promozionali.build(saggio_params)
    @saggio.destinatario = find_destinatario if params[:destinatario_value].present?

    if @saggio.save
      redirect_to scuola_path(@scuola), notice: "Saggio aggiunto"
    else
      redirect_to scuola_path(@scuola), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    @saggio = @scuola.saggi_promozionali.find(params[:id])
    if @saggio.update(saggio_params)
      redirect_to scuola_path(@scuola)
    else
      redirect_to scuola_path(@scuola), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio = @scuola.saggi_promozionali.find(params[:id])
    @saggio.destroy
    redirect_to scuola_path(@scuola)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.friendly.find(params[:scuola_id])
  end

  def saggio_params
    params.require(:saggio_promozionale).permit(:libro_id, :quantita, :stato, :note)
  end

  def find_destinatario
    klass_name, id = params[:destinatario_value].split(":")
    klass = klass_name.safe_constantize
    klass&.find_by(id: id)
  end
end
```

**Step 2: Add routes**

In `config/routes.rb`, inside `resources :scuole`:

```ruby
resource :saggi_promozionali, only: [:show], module: :scuole
resources :saggi_promozionali, only: [:create, :update, :destroy], module: :scuole
```

**Step 3: Commit**

```bash
git add app/controllers/scuole/saggi_promozionali_controller.rb config/routes.rb
git commit -m "feat: add saggi_promozionali controller for scuola context"
```

---

### Task 5: Scuola show — saggi section (lazy loaded)

**Files:**
- Create: `app/views/scuole/saggi_promozionali/show.html.erb`
- Create: `app/views/scuole/container/_saggi_promozionali.html.erb`
- Modify: scuola show to include lazy frame

**Step 1: Create container partial (lazy frame trigger)**

```erb
<%# locals: (scuola:) -%>

<%= turbo_frame_tag "scuola_saggi_promozionali",
    src: scuola_saggi_promozionali_path(scuola),
    loading: :lazy,
    style: "display: block; min-height: 1px;" do %>
  <section class="group">
    <h3 class="divider divider--fade divider--card txt-medium font-weight-black margin-block-end">Saggi promozionali</h3>
    <p class="txt-small txt-subtle margin-none">Caricamento...</p>
  </section>
<% end %>
```

**Step 2: Create show view (turbo frame content)**

```erb
<%= turbo_frame_tag "scuola_saggi_promozionali" do %>
  <section class="group">
    <h3 class="divider divider--fade divider--card txt-medium font-weight-black margin-block-end">
      Saggi promozionali
      <% if @saggi.any? %>
        <span class="txt-x-small txt-subtle font-weight-normal">(<%= @saggi.size %>)</span>
      <% end %>
      <% if @da_scaricare_count > 0 %>
        <span class="txt-x-small txt-accent font-weight-normal">
          <%= @da_scaricare_count %> da scaricare
        </span>
      <% end %>
    </h3>

    <% if @saggi.any? %>
      <%# Raggruppati per destinatario %>
      <% grouped = @saggi.group_by { |s| s.destinatario || @scuola } %>
      <% grouped.each do |dest, saggi| %>
        <h4 class="txt-x-small txt-subtle txt-uppercase margin-block-start">
          <% if dest.is_a?(Persona) %>
            <%= link_to dest.nome_completo, scuola_persona_path(@scuola, dest), class: "txt-link" %>
          <% elsif dest.is_a?(Classe) %>
            Classe <%= dest.nome_breve %>
          <% else %>
            Scuola
          <% end %>
        </h4>
        <dl class="dl-grid dl-grid--center txt-small">
          <% saggi.each do |saggio| %>
            <dt class="txt-x-small" style="line-height: 1.1;">
              <span class="font-weight-bold"><%= link_to saggio.libro.titolo, saggio.libro, class: "txt-link" %></span>
              <br><span class="txt-xx-small txt-subtle"><%= saggio.libro.editore&.editore %></span>
            </dt>
            <dd class="flex align-center gap-half">
              <span class="badge <%= saggio.consegnato? ? 'txt-positive' : 'txt-accent' %>">
                <%= saggio.stato %>
              </span>
              <span class="txt-xx-small txt-subtle">x<%= saggio.quantita %></span>
              <% if saggio.scaricato? %>
                <span class="txt-xx-small txt-subtle">scaricato</span>
              <% end %>
            </dd>
          <% end %>
        </dl>
      <% end %>
    <% end %>

    <%# Inline form %>
    <%= form_with model: SaggioPromozionale.new,
        url: scuola_saggi_promozionali_path(@scuola),
        class: "flex gap-half align-end flex-wrap margin-block-start" do |f| %>
      <fieldset class="flex-item-grow" style="flex-basis: 150px;">
        <label class="txt-xx-small txt-subtle txt-uppercase">Destinatario</label>
        <%= text_field_tag :destinatario_value, nil,
            placeholder: "Insegnante o classe...",
            class: "input full-width" %>
      </fieldset>
      <fieldset class="flex-item-grow" style="flex-basis: 200px;">
        <label class="txt-xx-small txt-subtle txt-uppercase">Libro</label>
        <%= f.combobox :libro_id, libri_path(format: :json),
            placeholder: "Cerca libro...",
            class: "input full-width" %>
      </fieldset>
      <fieldset>
        <label class="txt-xx-small txt-subtle txt-uppercase">Stato</label>
        <%= f.select :stato, [["Prenotato", "prenotato"], ["Consegnato", "consegnato"]],
            {}, class: "input" %>
      </fieldset>
      <fieldset style="width: 60px;">
        <label class="txt-xx-small txt-subtle txt-uppercase">Qtà</label>
        <%= f.number_field :quantita, value: 1, min: 1, class: "input full-width" %>
      </fieldset>
      <%= f.submit "Aggiungi", class: "btn btn--primary btn--small" %>
    <% end %>

    <%# Bottone genera scarico %>
    <% if @da_scaricare_count > 0 %>
      <div class="margin-block-start">
        <%= button_to "Genera scarico campionario (#{@da_scaricare_count})",
            genera_scarico_scuola_saggi_promozionali_path(@scuola),
            method: :post,
            class: "btn btn--ghost txt-small",
            data: { turbo_confirm: "Generare il documento di scarico campionario per #{@da_scaricare_count} saggi?" } %>
      </div>
    <% end %>
  </section>
<% end %>
```

**Step 3: Include in scuola show**

Add the lazy frame partial in the scuola show, after existing sections.

**Step 4: Commit**

```bash
git add app/views/scuole/saggi_promozionali/ app/views/scuole/container/_saggi_promozionali.html.erb
git commit -m "feat: add saggi promozionali section to scuola show"
```

---

### Task 6: Genera scarico campionario (document generation)

**Files:**
- Create: `app/models/saggio_promozionale/scarico_campionario.rb`
- Modify: `app/controllers/scuole/saggi_promozionali_controller.rb`
- Modify: `config/routes.rb`

**Step 1: Create service object**

```ruby
class SaggioPromozionale::ScaricoCampionario
  attr_reader :scuola, :saggi, :documento

  def initialize(scuola)
    @scuola = scuola
    @saggi = scuola.saggi_promozionali.da_scaricare.includes(:libro)
  end

  def genera!
    return nil if saggi.empty?

    causale = Causale.find_by(magazzino: "campionario", tipo_movimento: :vendita, movimento: :uscita)
    raise "Causale campionario non trovata" unless causale

    ActiveRecord::Base.transaction do
      @documento = Documento.create!(
        account: Current.account,
        user: Current.user,
        causale: causale,
        clientable: scuola,
        data_documento: Date.current,
        numero_documento: next_numero(causale)
      )

      # Raggruppa per libro e somma quantità
      saggi.group_by(&:libro_id).each_with_index do |(libro_id, libro_saggi), idx|
        libro = libro_saggi.first.libro
        quantita_totale = libro_saggi.sum(&:quantita)

        riga = Riga.create!(
          libro: libro,
          quantita: quantita_totale,
          prezzo_cents: 0,
          prezzo_copertina_cents: libro.prezzo_cents || 0
        )

        doc_riga = documento.documento_righe.create!(
          riga: riga,
          posizione: idx + 1
        )

        # Collega i saggi alla riga documento
        libro_saggi.each { |s| s.update!(documento_riga: doc_riga) }
      end

      documento.ricalcola_totali!
    end

    documento
  end

  private

  def next_numero(causale)
    ultimo = Documento.where(account: Current.account, causale: causale)
      .where("data_documento >= ?", Date.current.beginning_of_year)
      .maximum(:numero_documento)
    (ultimo || 0) + 1
  end
end
```

**Step 2: Add route and controller action**

Route:
```ruby
resource :saggi_promozionali, only: [:show] do
  post :genera_scarico, on: :member
end
```

Controller action:
```ruby
def genera_scarico
  service = SaggioPromozionale::ScaricoCampionario.new(@scuola)
  documento = service.genera!

  if documento
    redirect_to scuola_path(@scuola), notice: "Scarico campionario generato: #{documento.numero_documento}"
  else
    redirect_to scuola_path(@scuola), alert: "Nessun saggio da scaricare"
  end
end
```

**Step 3: Create causale seed (if not existing)**

Ensure a causale exists for campionario. Add to seeds or create via console:
```ruby
Causale.find_or_create_by!(
  causale: "SAGGIO",
  tipo_movimento: :vendita,
  movimento: :uscita,
  magazzino: "campionario"
)
```

**Step 4: Commit**

```bash
git add app/models/saggio_promozionale/ app/controllers/scuole/saggi_promozionali_controller.rb config/routes.rb
git commit -m "feat: genera scarico campionario from saggi promozionali"
```

---

### Task 7: Combobox libro con suggerimenti (da adozioni)

**Files:**
- Create: `app/controllers/scuole/saggi_promozionali/libri_controller.rb` (or modify existing libri endpoint)
- Modify: combobox in saggi forms

**Step 1: Create endpoint that returns suggested libri**

The libri combobox endpoint should accept a `scuola_id` param and return:
1. First: libri adottati nella scuola (from adozioni)
2. Then: all other libri matching search

```ruby
class Scuole::SaggiPromozionali::LibriController < ApplicationController
  before_action :authenticate_user!

  def index
    @scuola = Current.account.scuole.friendly.find(params[:scuola_id])

    if params[:q].present?
      @libri = Current.account.libri.search_all_word(params[:q]).limit(20)
    else
      # Suggerimenti: libri adottati in questa scuola
      isbn_adottati = @scuola.adozioni.distinct.pluck(:codice_isbn)
      @libri = Current.account.libri.where(codice_isbn: isbn_adottati).limit(20)
    end

    render partial: "scuole/saggi_promozionali/libri/libro",
           collection: @libri, as: :libro
  end
end
```

**Step 2: Add route**

```ruby
# Inside scuole resources
resource :saggi_promozionali do
  resources :libri, only: [:index], module: "saggi_promozionali"
end
```

**Step 3: Create combobox option partial**

```erb
<%# locals: (libro:) -%>
<%= tag.li id: libro.id,
    role: "option",
    data: { autocompletable_as: libro.to_combobox_display } do %>
  <span class="font-weight-bold"><%= libro.titolo %></span>
  <span class="txt-xx-small txt-subtle"><%= libro.codice_isbn %></span>
<% end %>
```

**Step 4: Update combobox in forms to point to scuola-specific endpoint**

Replace `libri_path(format: :json)` with `scuola_saggi_promozionali_libri_path(scuola)` in the saggi forms.

**Step 5: Commit**

```bash
git add app/controllers/scuole/saggi_promozionali/ app/views/scuole/saggi_promozionali/
git commit -m "feat: combobox libro with adoption suggestions for saggi"
```

---

## Notes

- **Causale campionario**: deve esistere prima di poter generare lo scarico. Verificare che esista o crearla.
- **Destinatario combobox nella scuola**: per la prima versione un text_field con l'id della persona è sufficiente. Nella prossima iterazione si può fare un combobox persone della scuola.
- **Giacenza campionario**: non serve nessuna modifica alla Views::Giacenza — i movimenti passano dal sistema documenti standard e la view li legge già (filtrando per causale.magazzino se necessario, o come totale generale).
- **Turbo responses**: i controller fanno redirect semplici. Nella prossima iterazione si possono convertire in turbo_stream per UX più fluida.
