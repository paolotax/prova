# Ritiro Bolle Visione — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Aggiungere il flusso di ritiro libri a fine anno: dalla pagina Scuola l'utente vede tutte le righe aperte delle bolle visione, le seleziona e genera documenti (Scarico Saggi / TD01 / Ordine Scuola / Mancante) con clientable scelto caso per caso. Supporta rientro one-click, split fascicoli, e creazione bolle retro-attive da collane multiple.

**Architecture:** `BollaVisioneRiga` ottiene `esito` (enum), `processato_at`, `documento_riga_id` (1:1 verso `DocumentoRiga`). Una nuova causale "Mancante" viene seedata. `RitiriController` gestisce la pagina di ritiro per scuola e la generazione dei documenti via service `Ritiro::CreaDocumento`. Pattern UI: bulk_actions + bulk_bar esistenti (vedi `app/views/appunti/bulk_bar/_bar.html.erb`); dialog Stimulus per selezione fascicoli mancanti.

**Tech Stack:** Rails 8.1, PostgreSQL, Stimulus, Turbo Streams, Minitest + fixtures, Docker (`docker exec prova-app-1`).

**Reference design:** `docs/plans/2026-05-06-ritiro-bolle-visione-design.md`

**Fizzy patterns:** dialog (`/home/paolotax/rails_2023/fizzy/app/views/cards/_delete.html.erb`), multi-selection (`multi_selection_combobox_controller.js`), panel layout. Riusiamo i pattern già adattati nel progetto (bulk_actions/bulk_bar).

**Mobile-first:** L'utente userà il flusso **dal cellulare in scuola** (no laptop). Tutta la UI deve essere ottimizzata per touch:
- Touch target ≥ 44×44px (iOS HIG / WCAG 2.5.5)
- Niente hover-only (tutto deve essere visibile/accessibile via tap)
- Layout verticale, full-width, font ≥ 16px
- Bulk bar già `position: fixed` (top center) — verificare che resti accessibile sopra la tastiera virtuale
- Dialog `<dialog>` deve diventare full-width o bottom-sheet su viewport piccoli (esiste già `dialog.css` da rivedere)
- Checkbox: usa `.input--checkbox` con padding label, in modo che tutta la riga sia cliccabile
- Bottoni "Rientro" e azioni veloci: minimo 40px alti, icona + testo (non solo icona)
- Test sistema: usare anche viewport mobile (`375×812`) per verificare

---

## Conventions

- **Italiano per dominio**, English per code
- **Tutti i comandi Rails dentro Docker:** `docker exec prova-app-1 bin/rails ...`
- **AccountScoped** concern per modelli multi-tenant
- **Current.account / Current.user** per scoping
- **Test:** Minitest + fixtures YAML (NO factories, NO RSpec)
- **Commits:** uno per task, messaggio in italiano nello stile dei commit recenti (`feat(...)`, `fix(...)`, `refactor(...)`)
- **Annotate** sempre dopo migration: `docker exec prova-app-1 bundle exec annotaterb models`
- **Mobile-first ovunque**: ogni partial/vista nuova deve essere testata a `375×812` (iPhone SE) prima del commit. Niente media query desktop-only senza il caso mobile coperto.

---

## Task 1: Migrazione `bolla_visione_righe` per stato di ritiro

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_ritiro_to_bolla_visione_righe.rb`
- Modify: `db/schema.rb` (auto-aggiornato dalla migration)
- Modify: `app/models/bolla_visione_riga.rb` (annotate)

**Step 1: Genera migration**

```bash
docker exec prova-app-1 bin/rails g migration AddRitiroToBollaVisioneRighe esito:integer processato_at:datetime documento_riga:references
```

**Step 2: Modifica la migration**

Apri `db/migrate/*_add_ritiro_to_bolla_visione_righe.rb` e assicurati che sia:

```ruby
class AddRitiroToBollaVisioneRighe < ActiveRecord::Migration[8.1]
  def change
    add_column :bolla_visione_righe, :esito, :integer
    add_column :bolla_visione_righe, :processato_at, :datetime
    add_reference :bolla_visione_righe, :documento_riga, foreign_key: true
    add_index :bolla_visione_righe, [:bolla_visione_id, :esito]
    add_index :bolla_visione_righe, :processato_at
  end
end
```

**Step 3: Run migration**

```bash
docker exec prova-app-1 bin/rails db:migrate
docker exec prova-app-1 bundle exec annotaterb models
```

Expected: tabella aggiornata, schema annotato.

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb app/models/bolla_visione_riga.rb
git commit -m "feat(bolla_visione_riga): aggiunge esito/processato_at per flusso ritiro"
```

---

## Task 2: Enum `esito`, scope, association sul modello

**Files:**
- Modify: `app/models/bolla_visione_riga.rb`
- Test: `test/models/bolla_visione_riga_test.rb` (creare se manca)

**Step 1: Test scope `aperte`/`chiuse` ed enum**

`test/models/bolla_visione_riga_test.rb`:

```ruby
require "test_helper"

class BollaVisioneRigaTest < ActiveSupport::TestCase
  test "scope aperte ritorna righe senza processato_at" do
    riga = bolla_visione_righe(:aperta)
    assert_includes BollaVisioneRiga.aperte, riga
    assert_not_includes BollaVisioneRiga.chiuse, riga
  end

  test "scope chiuse ritorna righe con processato_at" do
    riga = bolla_visione_righe(:chiusa_in_saggio)
    assert_includes BollaVisioneRiga.chiuse, riga
    assert_not_includes BollaVisioneRiga.aperte, riga
  end

  test "esito enum mappa i 5 valori attesi" do
    assert_equal({ "in_saggio" => 0, "venduto_fattura" => 1, "venduto_corrispettivi" => 2,
                   "mancante" => 3, "rientrato" => 4 }, BollaVisioneRiga.esiti)
  end
end
```

**Step 2: Run test → fallisce**

```bash
docker exec prova-app-1 bin/rails test test/models/bolla_visione_riga_test.rb
```

Expected: NoMethodError o `undefined method 'aperte'`.

**Step 3: Aggiungi enum/scope/belongs_to nel modello**

`app/models/bolla_visione_riga.rb` (aggiungi prima di `validates`):

```ruby
enum :esito, {
  in_saggio: 0,
  venduto_fattura: 1,
  venduto_corrispettivi: 2,
  mancante: 3,
  rientrato: 4
}

belongs_to :documento_riga, optional: true

scope :aperte, -> { where(processato_at: nil) }
scope :chiuse, -> { where.not(processato_at: nil) }
```

**Step 4: Crea fixtures di base**

Creare `test/fixtures/bolle_visione.yml`, `test/fixtures/bolla_visione_righe.yml`, `test/fixtures/scuole.yml`, `test/fixtures/libri.yml`, `test/fixtures/categorie.yml`, `test/fixtures/editori.yml`, `test/fixtures/collane.yml`, `test/fixtures/collana_libri.yml`, se mancanti.

Esempio minimo per il test (se le fixtures sopra non esistono, crearle con un solo record per ognuna; verificare con `bin/rails db:fixtures:load RAILS_ENV=test` che caricano).

`test/fixtures/bolla_visione_righe.yml`:

```yaml
aperta:
  id: <%= SecureRandom.uuid %>
  account: prova
  bolla_visione: bv_uno
  libro: grammatica
  quantita: 1

chiusa_in_saggio:
  id: <%= SecureRandom.uuid %>
  account: prova
  bolla_visione: bv_uno
  libro: storia
  quantita: 1
  esito: 0
  processato_at: <%= 1.day.ago %>
```

(Stessa logica per le altre fixtures necessarie, copiando schema dai modelli esistenti.)

**Step 5: Run test → passa**

```bash
docker exec prova-app-1 bin/rails test test/models/bolla_visione_riga_test.rb
```

Expected: 3 tests, 0 failures.

**Step 6: Commit**

```bash
git add app/models/bolla_visione_riga.rb test/fixtures test/models/bolla_visione_riga_test.rb
git commit -m "feat(bolla_visione_riga): enum esito, scope aperte/chiuse, assoc documento_riga"
```

---

## Task 3: Causale "Mancante" via seed

**Files:**
- Modify: `db/seeds.rb` (o `db/seeds/causali.rb` se esiste split)
- Test: `test/models/causale_test.rb` (aggiungi un test esistenza)

**Step 1: Trova dove sono seedate le causali**

```bash
grep -rn "Causale" db/seeds* 2>/dev/null
```

**Step 2: Aggiungi seed per "Mancante"**

Nel file di seed appropriato:

```ruby
Causale.find_or_create_by!(causale: "Mancante") do |c|
  c.tipo_movimento = :carico
  c.movimento = :uscita
  c.magazzino = "campionario"
  c.clientable_type = "Scuola"
  c.priorita = 50
end
```

**Step 3: Esegui seed**

```bash
docker exec prova-app-1 bin/rails db:seed
docker exec prova-app-1 bin/rails runner "puts Causale.find_by(causale: 'Mancante').inspect"
```

Expected: oggetto Causale stampato, non nil.

**Step 4: Aggiungi fixture causali**

In `test/fixtures/causali.yml` aggiungi:

```yaml
mancante:
  causale: "Mancante"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 1
  clientable_type: "Scuola"
  priorita: 50

scarico_saggi:
  causale: "Scarico saggi"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 1
  clientable_type: "Scuola"
  priorita: 40

td01:
  causale: "TD01"
  magazzino: "vendita"
  tipo_movimento: 1
  movimento: 1
  priorita: 60

ordine_scuola:
  causale: "Ordine Scuola"
  magazzino: "vendita"
  tipo_movimento: 1
  movimento: 1
  priorita: 70
```

**Step 5: Commit**

```bash
git add db/seeds* test/fixtures/causali.yml
git commit -m "feat(causale): seed e fixture per causale Mancante (più altre causali standard di ritiro)"
```

---

## Task 4: Service `Ritiro::CreaDocumento` (cuore della generazione)

**Files:**
- Create: `app/services/ritiro/crea_documento.rb`
- Test: `test/services/ritiro/crea_documento_test.rb`

**Step 1: Test del service**

`test/services/ritiro/crea_documento_test.rb`:

```ruby
require "test_helper"

class Ritiro::CreaDocumentoTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:prova)
    Current.user = users(:paolo)
    @scuola = scuole(:una)
    @riga1 = bolla_visione_righe(:aperta)
    @riga2 = bolla_visione_righe(:aperta_due)
  end

  test "crea documento con causale, clientable e righe; chiude bolle_visione_righe" do
    documento = Ritiro::CreaDocumento.new(
      righe: [@riga1, @riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    ).call

    assert_equal causali(:scarico_saggi), documento.causale
    assert_equal @scuola, documento.clientable
    assert_equal 2, documento.documento_righe.count

    @riga1.reload
    assert_equal "in_saggio", @riga1.esito
    assert_not_nil @riga1.processato_at
    assert_not_nil @riga1.documento_riga_id
    assert_equal @riga1.libro_id, @riga1.documento_riga.riga.libro_id
  end

  test "rollback se causale non valida" do
    assert_no_difference "Documento.count" do
      assert_raises ActiveRecord::RecordInvalid do
        Ritiro::CreaDocumento.new(
          righe: [@riga1], causale: nil, clientable: @scuola, data: Date.current
        ).call
      end
    end
    @riga1.reload
    assert_nil @riga1.processato_at
  end
end
```

**Step 2: Run → fail**

```bash
docker exec prova-app-1 bin/rails test test/services/ritiro/crea_documento_test.rb
```

Expected: `NameError: uninitialized constant Ritiro`.

**Step 3: Implementa service**

`app/services/ritiro/crea_documento.rb`:

```ruby
module Ritiro
  class CreaDocumento
    CAUSALE_TO_ESITO = {
      "Scarico saggi" => :in_saggio,
      "TD01"          => :venduto_fattura,
      "Ordine Scuola" => :venduto_corrispettivi,
      "Mancante"      => :mancante
    }.freeze

    def initialize(righe:, causale:, clientable:, data:)
      @righe = righe
      @causale = causale
      @clientable = clientable
      @data = data
    end

    def call
      raise ActiveRecord::RecordInvalid.new(Documento.new) if @causale.nil?

      Documento.transaction do
        documento = build_documento
        documento.save!
        @righe.each_with_index { |bv_riga, idx| processa_riga(bv_riga, documento, idx) }
        documento
      end
    end

    private

    def build_documento
      Current.account.documenti.new(
        causale: @causale,
        clientable: @clientable,
        data_documento: @data,
        numero_documento: prossimo_numero,
        user: Current.user
      )
    end

    def prossimo_numero
      max = Current.account.documenti.where(causale: @causale).maximum(:numero_documento) || 0
      max + 1
    end

    def processa_riga(bv_riga, documento, idx)
      riga = Riga.create!(
        libro: bv_riga.libro,
        quantita: bv_riga.quantita,
        prezzo_cents: bv_riga.libro.prezzo_in_cents
      )
      doc_riga = documento.documento_righe.create!(riga: riga, posizione: idx)
      bv_riga.update!(
        esito: CAUSALE_TO_ESITO.fetch(@causale.causale),
        documento_riga: doc_riga,
        processato_at: Time.current
      )
    end
  end
end
```

**Step 4: Run → pass**

```bash
docker exec prova-app-1 bin/rails test test/services/ritiro/crea_documento_test.rb
```

Expected: 2 tests, 0 failures.

**Step 5: Commit**

```bash
git add app/services/ritiro test/services/ritiro
git commit -m "feat(ritiro): service CreaDocumento per generazione documenti da bolle_visione_righe"
```

---

## Task 5: `RitiriController#show` — pagina ritiro per scuola

**Files:**
- Create: `app/controllers/ritiri_controller.rb`
- Modify: `config/routes.rb`
- Create: `app/views/ritiri/show.html.erb`
- Test: `test/controllers/ritiri_controller_test.rb`

**Step 1: Routes**

In `config/routes.rb` aggiungi (dentro lo scope account-aware, accanto a `resources :scuole`):

```ruby
resources :scuole do
  resource :ritiro, only: [:show], controller: "ritiri"
end
```

(Verifica con `docker exec prova-app-1 bin/rails routes | grep ritir` che esista `scuola_ritiro GET /scuole/:scuola_id/ritiro(.:format)`).

**Step 2: Test integration**

`test/controllers/ritiri_controller_test.rb`:

```ruby
require "test_helper"

class RitiriControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:paolo)
    sign_in_as @user  # helper esistente; altrimenti vedi test/test_helper.rb
    @scuola = scuole(:una)
  end

  test "show mostra le righe aperte di tutte le bolle della scuola" do
    get scuola_ritiro_path(@scuola)
    assert_response :success
    assert_select "[data-bolla-visione-riga-id=?]", bolla_visione_righe(:aperta).id
    assert_select "[data-bolla-visione-riga-id=?]", bolla_visione_righe(:chiusa_in_saggio).id, count: 0
  end
end
```

**Step 3: Run → fail**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb
```

Expected: routing error o 404.

**Step 4: Implementa controller**

`app/controllers/ritiri_controller.rb`:

```ruby
class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    @bolle = @scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(bolla_visione_righe: { processato_at: nil })
      .includes(:collana, bolla_visione_righe: :libro)
      .distinct
      .ordered

    @righe_per_bolla = @bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe.aperte.includes(:libro).order(:position)
    end

    # Per raggruppamento per gruppo (CollanaLibro.gruppo)
    @gruppo_per_libro_e_collana = build_gruppo_lookup(@bolle)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def build_gruppo_lookup(bolle)
    collana_ids = bolle.map(&:collana_id).uniq
    CollanaLibro.where(collana_id: collana_ids)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
```

**Step 5: Implementa vista (struttura minima per il test)**

`app/views/ritiri/show.html.erb`:

```erb
<% @page_title = "Ritiro #{@scuola.denominazione}" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= back_link_to "Scuola", scuola_path(@scuola) %>
  </div>
  <h1 class="header__title"><%= @page_title %></h1>
<% end %>

<section class="panel panel--wide shadow center">
  <% if @bolle.empty? %>
    <p class="txt-subtle">Nessuna bolla visione aperta.</p>
    <%= render "crea_bolle_da_collane", scuola: @scuola %>
  <% else %>
    <%= render "ritiri/lista", righe_per_bolla: @righe_per_bolla, gruppo_per_libro_e_collana: @gruppo_per_libro_e_collana %>
  <% end %>
</section>
```

Crea anche partial vuoto `app/views/ritiri/_lista.html.erb` con contenuto minimo:

```erb
<% righe_per_bolla.each do |bolla, righe| %>
  <h3>BV-<%= bolla.numero %> — <%= bolla.collana.nome %></h3>
  <ul>
    <% righe.each do |riga| %>
      <li data-bolla-visione-riga-id="<%= riga.id %>">
        <%= riga.libro_titolo %>
      </li>
    <% end %>
  </ul>
<% end %>
```

E placeholder `app/views/ritiri/_crea_bolle_da_collane.html.erb` (verrà completato in Task 12):

```erb
<%# placeholder, vedi Task 12 %>
```

**Step 6: Run → pass**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb
```

Expected: 1 test, 0 failures.

**Step 7: Commit**

```bash
git add app/controllers/ritiri_controller.rb config/routes.rb app/views/ritiri test/controllers/ritiri_controller_test.rb
git commit -m "feat(ritiri): controller e show pagina ritiro per scuola con righe aperte"
```

---

## Task 6: Vista raggruppata per bolla → gruppo (CollanaLibro)

**Files:**
- Modify: `app/views/ritiri/_lista.html.erb`
- Test: aggiorna `RitiriControllerTest`

**Step 1: Test sull'organizzazione DOM**

Aggiungi a `test/controllers/ritiri_controller_test.rb`:

```ruby
test "show raggruppa righe per bolla e per gruppo collana" do
  get scuola_ritiro_path(@scuola)
  assert_select ".ritiro__bolla", minimum: 1
  assert_select ".ritiro__bolla .ritiro__gruppo", minimum: 1
  assert_select ".ritiro__riga", minimum: 1
end
```

**Step 2: Run → fail (assert_select non trova le classi)**

**Step 3: Aggiorna partial**

`app/views/ritiri/_lista.html.erb`:

```erb
<%= form_with url: scuola_ritiri_documenti_path(@scuola),
      method: :post,
      data: {
        controller: "bulk-actions",
        bulk_actions_open_value: false
      } do |f| %>

  <% righe_per_bolla.each do |bolla, righe| %>
    <div class="ritiro__bolla margin-block-start">
      <h3 class="divider divider--fade txt-medium font-weight-black">
        BV-<%= bolla.numero %> — <%= bolla.collana.nome %>
        <span class="txt-x-small txt-subtle">
          <%= l(bolla.data_bolla, format: :short) %>
        </span>
      </h3>

      <% gruppi = righe.group_by { |r| gruppo_per_libro_e_collana[[bolla.collana_id, r.libro_id]].presence || "Altro" } %>
      <% gruppi.each do |gruppo, righe_g| %>
        <div class="ritiro__gruppo">
          <h4 class="divider txt-small txt-uppercase txt-subtle"><%= gruppo %></h4>
          <ul class="flex flex-column unpad margin-none">
            <% righe_g.each do |riga| %>
              <%= render "ritiri/riga", riga: riga %>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
  <% end %>

  <%= render "ritiri/bulk_bar", scuola: @scuola %>
<% end %>
```

`app/views/ritiri/_riga.html.erb` (mobile-first: tutta la riga è una label cliccabile, il prezzo va sopra/a destra, "Rientro" come bottone full-text touch-friendly):

```erb
<li class="ritiro__riga"
    data-bolla-visione-riga-id="<%= riga.id %>">
  <label class="ritiro__riga-label flex align-center gap pad-block-half pad-inline-half"
         style="min-height: 56px;">
    <%= check_box_tag "bolla_visione_riga_ids[]", riga.id, false,
          class: "input input--checkbox",
          style: "min-width: 24px; min-height: 24px;",
          data: { action: "bulk-actions#toggle", bulk_actions_target: "checkbox" } %>

    <div class="flex-item-grow flex flex-column gap-quarter">
      <strong class="txt-medium"><%= riga.libro_titolo %></strong>
      <div class="txt-x-small txt-subtle flex flex-wrap gap-half">
        <span>ISBN <%= riga.libro_codice_isbn %></span>
        <% if riga.libro.fascicoli.any? %>
          <span>· <%= riga.libro.fascicoli.size %> fasc.</span>
        <% end %>
        <span class="font-weight-black txt-ink">
          <%= number_to_currency(riga.libro.prezzo_in_cents.to_f / 100, unit: "€") %>
        </span>
      </div>
    </div>
  </label>

  <div class="ritiro__riga-actions flex gap-half pad-inline-half pad-block-half">
    <%= button_to scuola_ritiro_riga_rientro_path(@scuola, riga),
          method: :patch,
          class: "btn btn--small",
          style: "min-height: 40px;" do %>
      <%= icon_tag "arrow-uturn-left", size: "small" %>
      <span>Rientro</span>
    <% end %>
    <% if riga.libro.fascicoli.any? %>
      <button type="button" class="btn btn--small"
              style="min-height: 40px;"
              data-action="dialog#open"
              data-dialog-id="fascicoli-<%= riga.id %>">
        <%= icon_tag "alert-triangle", size: "small" %>
        <span>Fascicoli</span>
      </button>
    <% end %>
  </div>
</li>
```

Note mobile:
- `min-height: 56px` sulla label garantisce target touch comodo
- prezzo nello stesso blocco del libro (no colonna separata, troppo stretta su mobile)
- bottoni "Rientro"/"Fascicoli" sono **sotto** la label, full-text, su una riga separata: niente icone-only
- la label-clickable copre tutta la riga (tutta la label triggera la checkbox)

**Step 4: Run → pass**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb
```

**Step 5: Commit**

```bash
git add app/views/ritiri test/controllers/ritiri_controller_test.rb
git commit -m "feat(ritiri): vista lista raggruppata per bolla e gruppo collana"
```

---

## Task 7: Bulk bar con i 4 form di azione

**Files:**
- Create: `app/views/ritiri/_bulk_bar.html.erb`

**Step 1: Test che il form sia presente**

In `RitiriControllerTest`:

```ruby
test "show contiene bulk bar con i 4 form azione" do
  get scuola_ritiro_path(@scuola)
  assert_select "form[action=?]", scuola_ritiri_documenti_path(@scuola)
  assert_select "[data-form-id='scarico_saggi']"
  assert_select "[data-form-id='td01']"
  assert_select "[data-form-id='ordine_scuola']"
  assert_select "[data-form-id='mancante']"
end
```

**Step 2: Run → fail**

**Step 3: Implementa partial bulk bar**

`app/views/ritiri/_bulk_bar.html.erb`:

```erb
<% content_for :bulk_bar_buttons do %>
  <% [["scarico_saggi", "Scarico Saggi", "gift"],
      ["td01", "Fattura TD01", "receipt"],
      ["ordine_scuola", "Ordine Scuola", "shopping-cart"],
      ["mancante", "Mancante", "alert-triangle"]].each do |form_id, label, icon| %>
    <button type="button" class="btn bulk-bar__btn"
            data-action="bulk-bar#showForm"
            data-bulk-bar-target="menuButton"
            data-form-id="<%= form_id %>">
      <%= icon_tag icon %>
      <span><%= label %></span>
    </button>
  <% end %>
<% end %>

<% content_for :bulk_bar_forms do %>
  <% causali_map = {
    "scarico_saggi" => Causale.find_by(causale: "Scarico saggi"),
    "td01"          => Causale.find_by(causale: "TD01"),
    "ordine_scuola" => Causale.find_by(causale: "Ordine Scuola"),
    "mancante"      => Causale.find_by(causale: "Mancante")
  } %>

  <% causali_map.each do |form_id, causale| %>
    <div class="bulk-bar__form" data-bulk-bar-target="form" data-form-id="<%= form_id %>">
      <span class="bulk-bar__form-title"><%= causale&.causale %></span>
      <%= form_with url: scuola_ritiri_documenti_path(scuola),
            method: :post,
            data: { bulk_actions_target: "form",
                    action: "turbo:submit-end->bulk-actions#hideAfterSubmit" } do |f| %>
        <%= f.hidden_field :causale_id, value: causale&.id %>
        <%= f.hidden_field :clientable_type, value: "Scuola" %>
        <%= f.hidden_field :clientable_id, value: scuola.id %>
        <%= f.hidden_field :data_documento, value: Date.current %>
        <div class="bulk-bar__form-actions">
          <button type="button" class="btn" data-action="bulk-bar#hideForm">Annulla</button>
          <%= f.submit "Crea documento", class: "btn btn--primary" %>
        </div>
      <% end %>
    </div>
  <% end %>
<% end %>

<%= render "shared/bulk_bar" %>
```

**Step 4: Run → pass**

**Step 5: Commit**

```bash
git add app/views/ritiri/_bulk_bar.html.erb test/controllers/ritiri_controller_test.rb
git commit -m "feat(ritiri): bulk bar con 4 azioni standard (saggio/TD01/ordine/mancante)"
```

---

## Task 8: `RitiriDocumentiController#create` — endpoint che usa il service

**Files:**
- Create: `app/controllers/ritiri_documenti_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/ritiri_documenti_controller_test.rb`

**Step 1: Routes**

```ruby
resources :scuole do
  resource :ritiro, only: [:show], controller: "ritiri" do
    resources :documenti, only: [:create], controller: "ritiri_documenti", as: "ritiri_documenti"
  end
end
```

Verifica route: `scuola_ritiri_documenti_path(@scuola)` → `POST /scuole/:scuola_id/ritiro/documenti`.

**Step 2: Test integration**

`test/controllers/ritiri_documenti_controller_test.rb`:

```ruby
require "test_helper"

class RitiriDocumentiControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:paolo)
    @scuola = scuole(:una)
    @riga = bolla_visione_righe(:aperta)
  end

  test "create genera documento Scarico Saggi e chiude le righe selezionate" do
    assert_difference -> { Documento.count } => 1,
                      -> { DocumentoRiga.count } => 1 do
      post scuola_ritiri_documenti_path(@scuola), params: {
        causale_id: causali(:scarico_saggi).id,
        clientable_type: "Scuola",
        clientable_id: @scuola.id,
        data_documento: Date.current,
        bolla_visione_riga_ids: [@riga.id]
      }
    end
    assert_redirected_to scuola_ritiro_path(@scuola)

    @riga.reload
    assert_equal "in_saggio", @riga.esito
    assert_not_nil @riga.processato_at
    assert_not_nil @riga.documento_riga_id
  end

  test "create con nessuna riga selezionata torna in show con flash" do
    post scuola_ritiri_documenti_path(@scuola), params: {
      causale_id: causali(:scarico_saggi).id,
      clientable_type: "Scuola",
      clientable_id: @scuola.id,
      data_documento: Date.current,
      bolla_visione_riga_ids: []
    }
    assert_redirected_to scuola_ritiro_path(@scuola)
    assert_match /seleziona/i, flash[:alert]
  end
end
```

**Step 3: Run → fail**

**Step 4: Implementa controller**

`app/controllers/ritiri_documenti_controller.rb`:

```ruby
class RitiriDocumentiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola
  before_action :set_righe

  def create
    if @righe.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una riga." and return
    end

    documento = Ritiro::CreaDocumento.new(
      righe: @righe,
      causale: Current.account.causali_per_ritiro.find(params[:causale_id]),
      clientable: clientable,
      data: params[:data_documento]
    ).call

    redirect_to scuola_ritiro_path(@scuola), notice: "Documento #{documento.causale.causale} creato (#{documento.documento_righe.count} righe)."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to scuola_ritiro_path(@scuola), alert: "Errore: #{e.message}"
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end

  def set_righe
    ids = Array(params[:bolla_visione_riga_ids]).reject(&:blank?)
    @righe = Current.account.bolla_visione_righe
      .where(id: ids)
      .where(processato_at: nil)
      .includes(:libro)
  end

  def clientable
    klass = params[:clientable_type].constantize
    klass.find(params[:clientable_id])
  end
end
```

Aggiungi a `Causale` (modello):

```ruby
def self.per_ritiro
  where(causale: ["Scarico saggi", "TD01", "Ordine Scuola", "Mancante"])
end
```

E in `Account`:

```ruby
def causali_per_ritiro
  Causale.per_ritiro
end
```

**Step 5: Run → pass**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_documenti_controller_test.rb
```

**Step 6: Commit**

```bash
git add app/controllers/ritiri_documenti_controller.rb config/routes.rb app/models/causale.rb app/models/account.rb test/controllers/ritiri_documenti_controller_test.rb
git commit -m "feat(ritiri): endpoint POST per generazione documenti dalla selezione"
```

---

## Task 9: Azione "Rientro" one-click su BollaVisioneRiga

**Files:**
- Modify: `app/controllers/bolla_visione_righe_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/bolla_visione_righe_controller_test.rb` (aggiorna)

**Step 1: Routes**

In `config/routes.rb` aggiungi sotto la route ritiro:

```ruby
resources :scuole do
  resource :ritiro, only: [:show], controller: "ritiri" do
    resources :documenti, only: [:create], controller: "ritiri_documenti", as: "ritiri_documenti"
    member do
      patch "righe/:id/rientro", to: "ritiri#rientro", as: "riga_rientro"
      patch "righe/:id/riapri",  to: "ritiri#riapri",  as: "riga_riapri"
    end
  end
end
```

(Path helper: `scuola_ritiro_riga_rientro_path(@scuola, riga)`).

**Step 2: Test integration**

```ruby
test "rientro chiude la riga senza documento" do
  patch scuola_ritiro_riga_rientro_path(@scuola, @riga)
  @riga.reload
  assert_equal "rientrato", @riga.esito
  assert_not_nil @riga.processato_at
  assert_nil @riga.documento_riga_id
end
```

**Step 3: Run → fail**

**Step 4: Implementa azioni nel controller**

In `app/controllers/ritiri_controller.rb` aggiungi:

```ruby
def rientro
  riga = @scuola.bolle_visione.joins(:bolla_visione_righe)
    .where(bolla_visione_righe: { id: params[:id] })
    .first
    .bolla_visione_righe.find(params[:id])

  riga.update!(esito: :rientrato, processato_at: Time.current)
  respond_to do |format|
    format.html { redirect_to scuola_ritiro_path(@scuola) }
    format.turbo_stream { render turbo_stream: turbo_stream.remove("bolla_visione_riga_#{riga.id}") }
  end
end

def riapri
  riga = ... # come sopra
  if riga.documento_riga.present?
    documento = riga.documento_riga.documento
    riga.documento_riga.destroy
    documento.destroy if documento.documento_righe.reload.empty?
  end
  riga.update!(esito: nil, processato_at: nil, documento_riga_id: nil)
  redirect_to bolla_visione_path(riga.bolla_visione)
end
```

(Pulisci la query duplicata in un private `find_riga`.)

**Step 5: Run → pass**

**Step 6: Commit**

```bash
git add app/controllers/ritiri_controller.rb config/routes.rb test
git commit -m "feat(ritiri): azione rientro one-click e riapri riga"
```

---

## Task 10: Tab "Ritiro" su Scuola show

**Files:**
- Modify: `app/views/scuole/show.html.erb`
- Possibly: `app/views/scuole/_ritiro_tab.html.erb`

**Step 1: Test che il link esista quando ci sono bolle aperte**

`test/controllers/scuole_controller_test.rb`:

```ruby
test "scuola show mostra link Ritiro se ha bolle aperte" do
  get scuola_path(@scuola)
  assert_select "a[href=?]", scuola_ritiro_path(@scuola), text: /Ritiro/
end
```

**Step 2: Run → fail**

**Step 3: Aggiungi link nel show**

In `app/views/scuole/show.html.erb` (cercare la sezione "actions" o "tabs"):

```erb
<% if @scuola.bolle_visione.joins(:bolla_visione_righe).where(bolla_visione_righe: { processato_at: nil }).exists? %>
  <%= link_to scuola_ritiro_path(@scuola), class: "btn btn--primary" do %>
    <%= icon_tag "package" %>
    <span>Ritiro (<%= @scuola.bolle_visione.joins(:bolla_visione_righe).where(bolla_visione_righe: { processato_at: nil }).count %>)</span>
  <% end %>
<% end %>
```

**Step 4: Run → pass**

**Step 5: Commit**

```bash
git add app/views/scuole/show.html.erb test/controllers/scuole_controller_test.rb
git commit -m "feat(scuole): link Ritiro su show quando esistono bolle aperte"
```

---

## Task 11: Mancante su confezione — split fascicoli

**Files:**
- Modify: `app/models/bolla_visione_riga.rb` (metodo `splitta_in_fascicoli!`)
- Modify: `app/controllers/ritiri_documenti_controller.rb`
- Create: `app/views/ritiri/_dialog_fascicoli.html.erb`
- Modify: `app/views/ritiri/_riga.html.erb` (toggle dialog se confezione)
- Test: aggiungi a `RitiriDocumentiControllerTest`

**Step 1: Test del metodo `splitta_in_fascicoli!`**

In `BollaVisioneRigaTest`:

```ruby
test "splitta_in_fascicoli! genera N righe-fascicolo e chiude la confezione" do
  riga = bolla_visione_righe(:confezione_aperta)  # libro = atlante (confezione di 3 fascicoli)
  fascicoli_mancanti = riga.libro.fascicoli.first(2)

  righe_nuove = riga.splitta_in_fascicoli!(fascicoli_mancanti, esito_confezione: :rientrato)

  assert_equal 2, righe_nuove.size
  assert_equal fascicoli_mancanti.map(&:id).sort, righe_nuove.map(&:libro_id).sort
  assert righe_nuove.all? { |r| r.mancante? }

  riga.reload
  assert_equal "rientrato", riga.esito
  assert_not_nil riga.processato_at
end
```

**Step 2: Run → fail**

**Step 3: Implementa metodo nel modello**

In `app/models/bolla_visione_riga.rb`:

```ruby
def splitta_in_fascicoli!(fascicoli, esito_confezione:)
  raise ArgumentError, "fascicoli vuoti" if fascicoli.blank?

  transaction do
    nuove = fascicoli.map do |fascicolo|
      bolla_visione.bolla_visione_righe.create!(
        libro: fascicolo,
        quantita: 1,
        account: account
      )
    end
    update!(esito: esito_confezione, processato_at: Time.current)
    nuove
  end
end
```

**Step 4: Run → pass test modello**

**Step 5: Aggiungi flusso nel controller**

In `RitiriDocumentiController#create`, prima di chiamare il service, intercepta caso Mancante con confezioni:

```ruby
if causale.causale == "Mancante" && params[:fascicoli_per_riga].present?
  righe_aggiuntive = []
  params[:fascicoli_per_riga].each do |riga_id, info|
    bv_riga = @righe.find { |r| r.id == riga_id }
    next unless bv_riga
    fascicoli = bv_riga.libro.fascicoli.where(id: info[:fascicolo_ids])
    nuove = bv_riga.splitta_in_fascicoli!(
      fascicoli,
      esito_confezione: info[:esito_confezione].to_sym
    )
    righe_aggiuntive.concat(nuove)
    @righe = @righe - [bv_riga]  # rimuove la confezione dalla lista del documento
  end
  @righe = @righe + righe_aggiuntive
end
```

**Step 6: Aggiungi dialog nella vista riga**

In `_riga.html.erb`, se `riga.libro.fascicoli.any?`, includi un dialog Stimulus per scelta fascicoli:

```erb
<% if riga.libro.fascicoli.any? %>
  <div data-controller="dialog" data-dialog-modal-value="true">
    <button type="button" class="btn btn--circle btn--link" data-action="dialog#open">
      <%= icon_tag "alert-triangle" %>
    </button>
    <dialog class="dialog panel fill-white shadow gap flex-column"
            style="--panel-size: 50ch"
            data-dialog-target="dialog">
      <h3>Fascicoli mancanti — <%= riga.libro_titolo %></h3>
      <% riga.libro.fascicoli.each do |f| %>
        <label>
          <%= check_box_tag "fascicoli_per_riga[#{riga.id}][fascicolo_ids][]", f.id %>
          <%= f.titolo %>
        </label>
      <% end %>
      <label>Esito confezione originale:
        <%= select_tag "fascicoli_per_riga[#{riga.id}][esito_confezione]",
              options_for_select([["Rientrato","rientrato"],["In saggio","in_saggio"]]) %>
      </label>
      <div class="flex gap-half justify-center">
        <button type="button" class="btn" data-action="dialog#close">Annulla</button>
        <button type="button" class="btn btn--primary" data-action="dialog#close">Conferma</button>
      </div>
    </dialog>
  </div>
<% end %>
```

(Quando l'utente clicca "Conferma" non submitta direttamente — i campi nascosti vengono raccolti nel form bulk-actions perché vivono dentro lo stesso `<form>` parent.)

**Step 7: Test integration con confezione**

```ruby
test "create Mancante su confezione: splitta fascicoli e crea documento" do
  confezione = bolla_visione_righe(:confezione_aperta)
  fascicoli_ids = confezione.libro.fascicoli.first(2).map(&:id)

  assert_difference -> { BollaVisioneRiga.count } => 2,
                    -> { Documento.count } => 1 do
    post scuola_ritiri_documenti_path(@scuola), params: {
      causale_id: causali(:mancante).id,
      clientable_type: "Scuola",
      clientable_id: @scuola.id,
      data_documento: Date.current,
      bolla_visione_riga_ids: [confezione.id],
      fascicoli_per_riga: {
        confezione.id => { fascicolo_ids: fascicoli_ids, esito_confezione: "rientrato" }
      }
    }
  end

  documento = Documento.last
  assert_equal 2, documento.documento_righe.count
  confezione.reload
  assert_equal "rientrato", confezione.esito
end
```

**Step 8: Run → pass**

**Step 9: Commit**

```bash
git add app/models/bolla_visione_riga.rb app/controllers/ritiri_documenti_controller.rb app/views/ritiri test
git commit -m "feat(ritiri): split fascicoli mancanti su confezione (causale Mancante)"
```

---

## Task 12: Crea bolle retro da collane multiple

**Files:**
- Create: `app/controllers/bolle_visione_da_collane_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/views/ritiri/_crea_bolle_da_collane.html.erb`
- Test: `test/controllers/bolle_visione_da_collane_controller_test.rb`

**Step 1: Routes**

```ruby
resources :scuole do
  resource :ritiro, only: [:show], controller: "ritiri" do
    # ...
    resources :bolle_da_collane, only: [:create], controller: "bolle_visione_da_collane"
  end
end
```

**Step 2: Test**

```ruby
test "create genera N BollaVisione da N collane selezionate" do
  assert_difference -> { BollaVisione.count } => 2 do
    post scuola_ritiro_bolle_da_collane_path(@scuola), params: {
      collana_ids: [collane(:una).id, collane(:due).id]
    }
  end
  assert_redirected_to scuola_ritiro_path(@scuola)
end
```

**Step 3: Run → fail**

**Step 4: Implementa controller**

`app/controllers/bolle_visione_da_collane_controller.rb`:

```ruby
class BolleVisioneDaCollaneController < ApplicationController
  before_action :authenticate_user!

  def create
    scuola = Current.account.scuole.find(params[:scuola_id])
    collana_ids = Array(params[:collana_ids]).reject(&:blank?)

    BollaVisione.transaction do
      collana_ids.each do |cid|
        collana = Current.account.collane.find(cid)
        bv = scuola.bolle_visione.create!(
          collana: collana,
          data_bolla: Date.current,
          user: Current.user,
          note: "Bolla creata in fase di ritiro"
        )
        bv.crea_righe_da_collana!
      end
    end

    redirect_to scuola_ritiro_path(scuola), notice: "#{collana_ids.size} bolle create."
  end
end
```

**Step 5: Vista form**

`app/views/ritiri/_crea_bolle_da_collane.html.erb`:

```erb
<%= form_with url: scuola_ritiro_bolle_da_collane_path(scuola), method: :post,
              class: "panel panel--inset margin-block-start" do |f| %>
  <h3 class="txt-medium font-weight-black">Crea bolle da collane</h3>
  <div class="flex flex-column gap-half">
    <% Current.account.collane.ordered.each do |collana| %>
      <label>
        <%= check_box_tag "collana_ids[]", collana.id, false, class: "input input--checkbox" %>
        <%= collana.nome %>
      </label>
    <% end %>
  </div>
  <div class="flex justify-end margin-block-start-half">
    <%= f.submit "Crea bolle", class: "btn btn--primary" %>
  </div>
<% end %>
```

**Step 6: Run → pass**

**Step 7: Commit**

```bash
git add app/controllers/bolle_visione_da_collane_controller.rb config/routes.rb app/views/ritiri/_crea_bolle_da_collane.html.erb test
git commit -m "feat(ritiri): crea bolle visione retro-attive da collane multiple"
```

---

## Task 13: Splitta riga (quantità > 1) — eccezione

**Files:**
- Add action `split` su `BollaVisioneRigaController` (o estendi `RitiriController`)
- Modify: `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb`
- Test

**Step 1: Test split**

```ruby
test "split divide la riga quantita 3 in 3 righe quantita 1" do
  riga = bolla_visione_righe(:multipla_quantita_3)
  assert_difference -> { BollaVisioneRiga.count } => 2 do  # +3 nuove, -1 originale = +2
    riga.splitta!
  end
  riga.reload rescue nil
  assert_nil riga.id || ActiveRecord::RecordNotFound  # confirmed deleted
end
```

**Step 2: Run → fail**

**Step 3: Implementa metodo modello**

```ruby
def splitta!
  return self if quantita <= 1
  transaction do
    quantita.times do
      bolla_visione.bolla_visione_righe.create!(
        libro: libro,
        classi_target: classi_target,
        quantita: 1,
        account: account
      )
    end
    destroy!
  end
end
```

**Step 4: UI bottone**

Sulla riga in `_riga.html.erb`, mostra solo se `riga.quantita > 1`:

```erb
<% if riga.quantita > 1 %>
  <%= button_to "Splitta", scuola_ritiro_riga_split_path(@scuola, riga),
        method: :patch, class: "btn btn--link txt-small" %>
<% end %>
```

**Step 5: Commit**

```bash
git add app/models/bolla_visione_riga.rb app/controllers app/views config/routes.rb test
git commit -m "feat(bolla_visione_riga): azione split per righe con quantita > 1"
```

---

## Task 14: Tab "Bolle aperte" su Tappa show

**Files:**
- Modify: `app/views/tappe/show.html.erb` (o partial appropriato)

**Step 1: Test**

```ruby
test "tappa show mostra link al ritiro della scuola se ha bolle aperte" do
  tappa = tappe(:una_con_scuola)
  get tappa_path(tappa)
  assert_select "a[href=?]", scuola_ritiro_path(tappa.tappable)
end
```

**Step 2: Run → fail**

**Step 3: Aggiungi sezione**

In `app/views/tappe/show.html.erb`, dove la tappa è di tipo `Scuola`:

```erb
<% if @tappa.tappable.is_a?(Scuola) && @tappa.tappable.bolle_visione.joins(:bolla_visione_righe).where(bolla_visione_righe: { processato_at: nil }).exists? %>
  <div class="panel panel--inset margin-block-start">
    <h3 class="txt-medium font-weight-black">Bolle visione da ritirare</h3>
    <%= link_to scuola_ritiro_path(@tappa.tappable), class: "btn btn--primary" do %>
      <%= icon_tag "package" %>
      <span>Vai al ritiro</span>
    <% end %>
  </div>
<% end %>
```

**Step 4: Run → pass**

**Step 5: Commit**

```bash
git add app/views/tappe test
git commit -m "feat(tappe): card link al ritiro per scuole con bolle aperte"
```

---

## Task 15: Show BollaVisione — badge esito su righe chiuse + Riapri

**Files:**
- Modify: `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb`

**Step 1: Test**

```ruby
test "show bolla mostra badge esito sulle righe chiuse" do
  bv = bolle_visione(:bv_uno)
  riga = bolla_visione_righe(:chiusa_in_saggio)  # appartiene a bv_uno
  get bolla_visione_path(bv)
  assert_select "[data-bolla-visione-riga-id='#{riga.id}'] .badge", text: /saggio/i
end
```

**Step 2: Run → fail (probabilmente)**

**Step 3: Aggiorna partial**

In `_bolla_visione_riga.html.erb`, alla fine della riga:

```erb
<% if riga.processato_at.present? %>
  <span class="badge badge--<%= riga.esito %>">
    <%= t("bolla_visione_riga.esiti.#{riga.esito}") %>
  </span>
  <% if riga.documento_riga.present? %>
    <%= link_to "Doc.", documento_path(riga.documento_riga.documento), class: "txt-small" %>
  <% end %>
  <%= button_to "Riapri", scuola_ritiro_riga_riapri_path(scuola: riga.bolla_visione.scuola, id: riga.id),
        method: :patch, class: "btn btn--link txt-small",
        data: { turbo_confirm: "Riaprire la riga?" } %>
<% end %>
```

Aggiungi `config/locales/it.yml`:

```yaml
it:
  bolla_visione_riga:
    esiti:
      in_saggio: "In saggio"
      venduto_fattura: "Venduto (TD01)"
      venduto_corrispettivi: "Ordine scuola"
      mancante: "Mancante"
      rientrato: "Rientrato"
```

**Step 4: Run → pass**

**Step 5: Commit**

```bash
git add app/views/bolla_visione_righe config/locales/it.yml test
git commit -m "feat(bolla_visione): badge esito e azione Riapri su righe chiuse"
```

---

## Task 16: System test end-to-end

**Files:**
- Create: `test/system/ritiro_test.rb`

**Step 1: Test E2E**

```ruby
require "application_system_test_case"

class RitiroTest < ApplicationSystemTestCase
  setup do
    sign_in_as users(:paolo)
  end

  test "flusso completo: scuola → ritiro → seleziona righe → genera Scarico Saggi" do
    visit scuola_path(scuole(:una))
    click_on "Ritiro"

    assert_text "BV-"

    # seleziona prime 2 righe
    all("input[type=checkbox][name='bolla_visione_riga_ids[]']").first(2).each(&:click)

    click_on "Scarico Saggi"
    click_on "Crea documento"

    assert_text "Documento Scarico saggi creato"
  end

  test "rientro one-click rimuove la riga dalla lista" do
    visit scuola_ritiro_path(scuole(:una))
    riga = bolla_visione_righe(:aperta)

    within "[data-bolla-visione-riga-id='#{riga.id}']" do
      click_button "Rientro"
    end

    assert_no_selector "[data-bolla-visione-riga-id='#{riga.id}']"
  end
end
```

**Step 2: Run**

```bash
docker exec prova-app-1 bin/rails test:system test/system/ritiro_test.rb
```

(Se richiede browser headless, segui setup esistente del progetto.)

**Step 3: Commit**

```bash
git add test/system/ritiro_test.rb
git commit -m "test(ritiri): system test end-to-end del flusso ritiro"
```

---

## Task 17: Smoke test mobile (DevTools 375×812)

**Step 1: Apri Chrome DevTools mobile emulation**

```bash
bin/dev
```

In browser: DevTools → Toggle device toolbar → "iPhone SE" (375×667) o "iPhone 12 Pro" (390×844).

**Step 2: Verifica per ogni schermata**

Pagina ritiro `scuole/:id/ritiro`:
- [ ] header sticky in alto, back button toccabile
- [ ] righe full-width, label intera cliccabile, checkbox visibile e ≥ 24px
- [ ] prezzo leggibile (16px+), no troncamento titolo
- [ ] bottoni "Rientro"/"Fascicoli" visibili senza scroll orizzontale
- [ ] bulk-bar appare al primo tap sulla checkbox, non copre il bottone selezionato
- [ ] form bulk-bar (causale buttons) tappabili senza zoom

Dialog fascicoli (Task 11):
- [ ] dialog occupa quasi tutto lo schermo o almeno 90vw
- [ ] checkbox e label tap-area ≥ 44px
- [ ] bottoni "Annulla" / "Conferma" full-width o su riga propria

Crea bolle da collane (Task 12):
- [ ] lista checkbox collane, ognuna ≥ 44px
- [ ] submit button full-width

**Step 3: Verifica in Safari iOS reale (se possibile)**

Apri da iPhone reale `https://<dev-host>/scuole/X/ritiro` per validare:
- viewport, font sizing, tastiera virtuale che non copre il bottone submit
- Turbo Stream funziona senza reload

**Step 4: Fix eventuali regressioni CSS**

Se la bulk-bar viene coperta dalla tastiera virtuale o ha overflow, aggiungere a `app/assets/stylesheets/bulk-actions.css`:

```css
@media (max-width: 640px) {
  .bulk-bar {
    inset: auto auto var(--block-space) 50%;  /* sticky bottom su mobile */
    transform: translateX(-50%) translateY(150%);
  }
  .bulk-bar[data-visible] {
    transform: translateX(-50%) translateY(0);
  }
}
```

**Step 5: Commit eventuali fix**

```bash
git add app/assets/stylesheets app/views
git commit -m "fix(ritiri): mobile responsiveness della bulk bar e righe"
```

---

## Task 18: Smoke test manuale completo + cleanup

**Step 1: Avvia dev server e prova manualmente**

```bash
bin/dev
```

Apri browser su `localhost:3000`:

1. Login → vai su una scuola con bolle visione aperte
2. Clicca "Ritiro" → verifica lista raggruppata, prezzi, fascicoli
3. Seleziona 2 righe → "Scarico Saggi" → "Crea documento" → verifica redirect e flash
4. Su una riga confezione → dialog fascicoli → mark "Mancante" → verifica split e documento
5. Su una riga semplice → "Rientro" → riga sparisce
6. Vai sullo show della bolla → vedi badge "In saggio" sulla riga chiusa, link al doc
7. Clicca "Riapri" → riga torna aperta, doc cancellato

**Step 2: Verifica nessun warning Rails / errore JS**

```bash
docker logs prova-app-1 --tail 100
```

**Step 3: Run full test suite**

```bash
docker exec prova-app-1 bin/rails test
docker exec prova-app-1 bin/rails test:system
```

Expected: 0 failures.

**Step 4: Pull request**

Branch `feature/ritiro-bolle-visione` → push e apri PR contro `feature/multi-tenancy`.

```bash
git push -u origin feature/ritiro-bolle-visione
```

---

## Note di esecuzione

- **Test fixtures**: il progetto ha pochissime fixtures (solo `accounts`, `users`, `causali` parziale). Quasi ogni task richiederà di **creare nuove fixtures** per `scuole`, `libri`, `editori`, `categorie`, `collane`, `collana_libri`, `bolle_visione`, `bolla_visione_righe`. Tienilo in conto: il primo task che le richiede (Task 2) deve crearle tutte; i successivi le riutilizzano.
- **Auth helper**: verifica esistenza `sign_in_as` in `test/test_helper.rb`; se manca, usa `post sign_in_path(...)` o estendi il test helper.
- **Causali**: i nomi causale ("Scarico saggi", "TD01", "Ordine Scuola", "Mancante") sono stringhe sensibili. Tieni allineate fixture e seed.
- **`Riga` vs `DocumentoRiga`**: `DocumentoRiga` non ha `libro_id` diretto. Bisogna sempre creare prima una `Riga` (con libro/quantita/prezzo) e poi una `DocumentoRiga` che la referenzia. Vedi service in Task 4.
- **Numero documento**: non auto-assegnato; il service usa `max(:numero_documento) + 1` per causale. Verifica unicity con i documenti esistenti.
- **Pattern Fizzy**: dialog stimulus copiato da `cards/_delete.html.erb`; bulk_actions/bulk_bar già adattati nel progetto (vedi `app/views/appunti/bulk_bar/_bar.html.erb`).
- **AccountScoped**: tutti i nuovi controller devono filtrare via `Current.account` (non passare `account_id` come param).
- **CSS**: niente Tailwind. Usa classi del progetto (`btn`, `panel`, `divider`, `flex`, `gap-half`, ecc.) coerenti con Fizzy.
