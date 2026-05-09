# Refactor Ritiri + Bolle Visione Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Riorganizzare i controller del flusso ritiro+bolle_visione in due namespace coerenti (`Ritiri::` e `BolleVisione::`), trasformare `Ritiro::CreaDocumento` service in un PORO `Ritiro` unico, e unificare le custom action `rientro`/`riapri` in `update` con param `:esito`.

**Architecture:** Due namespace paralleli che riflettono le due fasi di vita di una `BollaVisioneRiga`: composizione (`BolleVisione::*`, sotto tappa) e lavorazione (`Ritiri::*`, in scuola). Il PORO `Ritiro` (in `app/models/`) incapsula sia la query di vista (bolle aperte+rientrate per scuola, raggruppamento per gruppo collana) sia il comando `crea_documento`. BaseController per namespace elimina duplicazione `set_scuola`/`set_bolla_visione`. Routes Rails-CRUD pulite via `scope module:`.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest fixtures, Turbo, Stimulus, Docker (`docker exec prova-app-1 bin/rails ...`).

**Spec di riferimento:** `docs/superpowers/specs/2026-05-09-refactor-ritiri-bolle-visione-design.md`

---

## File Map

**File da creare:**
- `app/models/ritiro.rb` — PORO entità di dominio (vista + crea_documento)
- `app/controllers/ritiri/base_controller.rb` — auth + set_scuola
- `app/controllers/ritiri/righe_controller.rb` — update esito (rientro/riapri unificati)
- `app/controllers/ritiri/documenti_controller.rb` — create Documento (rinomina da `RitiriDocumentiController`)
- `app/controllers/ritiri/bolle_controller.rb` — create N bolle da collane (rinomina da `BolleVisioneDaCollaneController`)
- `app/controllers/bolle_visione/base_controller.rb` — auth + set_bolla_visione
- `app/controllers/bolle_visione/righe_controller.rb` — CRUD righe composizione (rinomina da `BollaVisioneRigheController`)
- `test/models/ritiro_test.rb` — copertura PORO (vista + comandi)
- `test/controllers/ritiri/righe_controller_test.rb` — update esito
- `test/controllers/ritiri/documenti_controller_test.rb` — rinomina
- `test/controllers/ritiri/bolle_controller_test.rb` — create da collane
- `test/controllers/bolle_visione/righe_controller_test.rb` — rinomina

**File da modificare:**
- `app/controllers/ritiri_controller.rb` — solo `show`, usa PORO
- `app/controllers/bolle_visione_controller.rb` — `rigenera` come member action
- `app/views/ritiri/show.html.erb` — usa `@ritiro.*`
- `app/views/ritiri/_lista.html.erb` — usa `@ritiro.gruppo_per`
- `app/views/ritiri/_riga.html.erb` — PATCH unica con `:esito`
- `app/views/ritiri/_crea_bolle_da_collane.html.erb` — path helper aggiornato
- `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb` — path helpers aggiornati
- `app/views/scuole/_container.html.erb` — verifica path helper invariato
- `app/views/tappe/show.html.erb` — verifica path helper invariato
- `config/routes.rb` — nuove rotte
- `config/initializers/inflections.rb` — aggiungi `irregular 'bolla', 'bolle'`

**File da eliminare:**
- `app/services/ritiro/crea_documento.rb`
- `app/services/ritiro/` (directory vuota)
- `app/controllers/ritiri_documenti_controller.rb`
- `app/controllers/bolle_visione_da_collane_controller.rb`
- `app/controllers/bolla_visione_righe_controller.rb`
- `test/services/ritiro/crea_documento_test.rb`
- `test/services/ritiro/` (directory vuota)
- `test/controllers/ritiri_documenti_controller_test.rb`
- `test/controllers/bolla_visione_righe_controller_test.rb` (se esiste)

**Convenzione test runner:** tutti i test girano in container Docker:
```bash
docker exec prova-app-1 bin/rails test <path>
```

---

## Task 1: PORO `Ritiro` per la vista

**Obiettivo:** Estrarre la logica di vista da `RitiriController#show` in un PORO testabile, senza modificare ancora la creazione documento.

**Files:**
- Create: `app/models/ritiro.rb`
- Create: `test/models/ritiro_test.rb`
- Modify: `app/controllers/ritiri_controller.rb`
- Modify: `app/views/ritiri/show.html.erb`
- Modify: `app/views/ritiri/_lista.html.erb`

- [ ] **Step 1.1: Verifica baseline test verde**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb test/services/ritiro/crea_documento_test.rb
```

Atteso: tutti i test passano. Se qualcuno fallisce, fermati e segnala.

- [ ] **Step 1.2: Scrivi test del PORO `Ritiro` (vista)**

Crea `test/models/ritiro_test.rb`:

```ruby
require "test_helper"

class RitiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :editori, :categorie, :libri, :scuole,
           :collane, :collana_libri, :bolle_visione, :bolla_visione_righe, :causali

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @ritiro = Ritiro.new(@scuola)
  end

  test "bolle ritorna le bolle con almeno una riga aperta o rientrata" do
    assert_includes @ritiro.bolle, bolla_visione_righe(:aperta).bolla_visione
  end

  test "bolle non include bolle con tutte le righe processate (saggio/venduto/mancante)" do
    bv = bolla_visione_righe(:chiusa_in_saggio).bolla_visione
    bv.bolla_visione_righe.update_all(esito: BollaVisioneRiga.esiti[:in_saggio], processato_at: Time.current)
    refute_includes Ritiro.new(@scuola).bolle, bv
  end

  test "righe(bolla) ritorna le righe visibili (aperte + rientrate)" do
    bv = bolla_visione_righe(:aperta).bolla_visione
    righe = @ritiro.righe(bv)
    assert righe.any?
    assert(righe.all? { |r| r.processato_at.nil? || r.rientrato? })
  end

  test "gruppo_per(libro_id, collana_id) ritorna il gruppo da CollanaLibro" do
    riga = bolla_visione_righe(:aperta)
    bolla = riga.bolla_visione
    expected = CollanaLibro.find_by(collana_id: bolla.collana_id, libro_id: riga.libro_id)&.gruppo
    assert_equal expected, @ritiro.gruppo_per(riga.libro_id, bolla.collana_id)
  end

  test "empty? true quando non ci sono bolle" do
    @scuola.bolle_visione.destroy_all
    assert Ritiro.new(@scuola).empty?
  end
end
```

- [ ] **Step 1.3: Run test (deve fallire — Ritiro non esiste)**

```bash
docker exec prova-app-1 bin/rails test test/models/ritiro_test.rb
```

Atteso: errore tipo `NameError: uninitialized constant Ritiro` oppure `Ritiro::CreaDocumento` (perché `Ritiro` è oggi un modulo nei services).

- [ ] **Step 1.4: Crea il PORO `Ritiro`**

Crea `app/models/ritiro.rb`:

```ruby
class Ritiro
  attr_reader :scuola

  def initialize(scuola)
    @scuola = scuola
  end

  def bolle
    @bolle ||= scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
      .includes(:collana)
      .distinct.ordered
  end

  def righe(bolla)
    righe_per_bolla[bolla]
  end

  def gruppo_per(libro_id, collana_id)
    gruppo_lookup[[collana_id, libro_id]]
  end

  def empty?
    bolle.empty?
  end

  private

  def visibili_sql
    "bolla_visione_righe.processato_at IS NULL OR bolla_visione_righe.esito = ?"
  end

  def righe_per_bolla
    @righe_per_bolla ||= bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe
        .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
        .includes(:libro)
        .order(:position)
    end
  end

  def gruppo_lookup
    @gruppo_lookup ||= CollanaLibro.where(collana_id: bolle.map(&:collana_id).uniq)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end
end
```

**ATTENZIONE conflitto namespace:** Esiste oggi `app/services/ritiro/crea_documento.rb` con `module Ritiro`. Questo step può fallire perché Zeitwerk vede entrambi: `class Ritiro` in models e `module Ritiro` in services. Ruby permette di riaprire una classe come namespace, ma Zeitwerk si aspetta consistenza.

Se ottieni un `Zeitwerk::NameError` o errori simili, **non rinominare**: il problema sparisce al Task 2 quando cancelliamo il service. Per ora lascia il file e verifica se i test girano. Se Zeitwerk si rifiuta di caricare, **interrompi e segnala** — il piano va riordinato.

- [ ] **Step 1.5: Run test (deve passare)**

```bash
docker exec prova-app-1 bin/rails test test/models/ritiro_test.rb
```

Atteso: 5 run, 0 failures.

- [ ] **Step 1.6: Aggiorna `RitiriController#show` per usare il PORO**

Modifica `app/controllers/ritiri_controller.rb` — sostituisci `def show` esistente:

```ruby
def show
  @ritiro = Ritiro.new(@scuola)
end
```

**Lascia invariati** i metodi `rientro`, `riapri`, e i private `set_scuola`, `find_riga`, `build_gruppo_lookup`. Saranno rimossi al Task 4.

- [ ] **Step 1.7: Aggiorna `app/views/ritiri/show.html.erb`**

Sostituisci tutti i riferimenti `@bolle`, `@righe_per_bolla`, `@gruppo_per_libro_e_collana` con accessor del PORO.

Il file diventa:

```erb
<% @page_title = "Ritiro" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= back_link_to "Scuola", scuola_path(@scuola) %>
  </div>
  <h1 class="header__title"><%= @page_title %></h1>
<% end %>

<section class="panel panel--wide shadow center">
  <div class="flex align-center gap-half">
    <h3 class="divider divider--fade txt-medium font-weight-black margin-none" style="flex: 1;">
      <%= link_to @scuola.denominazione, scuola_path(@scuola) %>
    </h3>
  </div>

  <div class="flex flex-wrap gap full-width">
    <div class="flex-item-grow" style="flex-basis: 120px;">
      <span class="txt-x-small txt-subtle txt-uppercase">Bolle aperte</span>
      <div class="txt-medium"><%= @ritiro.bolle.size %></div>
    </div>
    <div class="flex-item-grow" style="flex-basis: 120px;">
      <span class="txt-x-small txt-subtle txt-uppercase">Righe da processare</span>
      <div class="txt-medium"><%= @ritiro.bolle.sum { |b| @ritiro.righe(b).count { |r| r.processato_at.nil? } } %></div>
    </div>
    <div class="flex-item-grow" style="flex-basis: 120px;">
      <span class="txt-x-small txt-subtle txt-uppercase">Data</span>
      <div class="txt-medium"><%= l(Date.current, format: :short) %></div>
    </div>
  </div>

  <% if @ritiro.empty? %>
    <p class="txt-subtle margin-block-start">Nessuna bolla visione aperta.</p>
    <%= render "crea_bolle_da_collane", scuola: @scuola %>
  <% else %>
    <%= render "ritiri/lista", ritiro: @ritiro %>
  <% end %>
</section>
```

- [ ] **Step 1.8: Aggiorna `app/views/ritiri/_lista.html.erb`**

Riceve ora `ritiro:` invece di `righe_per_bolla:` e `gruppo_per_libro_e_collana:`. Sostituisci tutto il file:

```erb
<%# Container bulk-actions: i form vivono dentro `_bulk_bar` e ricevono via #syncSelection %>
<%# gli ID dei checkbox selezionati come hidden inputs `bolla_visione_riga_ids[]`. %>
<%= tag.div data: { controller: "bulk-actions" } do %>

  <% ritiro.bolle.each do |bolla| %>
    <% righe = ritiro.righe(bolla) %>
    <div class="ritiro__bolla">

      <div class="flex align-center gap-half margin-block-start">
        <h3 class="divider divider--fade txt-medium font-weight-black margin-none" style="flex: 1;">
          <%= link_to "BV-#{bolla.numero}", bolla_visione_path(bolla) %>
        </h3>
      </div>

      <span class="txt-small txt-subtle font-weight-normal"><%= bolla.collana.nome %>&middot;</span>
      <span class="txt-x-small txt-subtle flex-item-no-shrink">
        <%= l(bolla.data_bolla, format: :short) %>
      </span>
      <% gruppi = righe.group_by { |r| ritiro.gruppo_per(r.libro_id, bolla.collana_id).presence || "Altro" } %>
      <% gruppi.each do |gruppo, righe_g| %>

        <div class="flex-colunms align-center gap-half margin-block-start">
          <h3 class="divider divider--fade txt-medium font-weight-black margin-none" style="flex: 1;">
            <%= gruppo.presence || "Altro" %>
          </h3>

          <ul class="flex flex-column unpad margin-none">
            <% righe_g.each do |riga| %>
              <%= render "ritiri/riga", riga: riga, scuola: @scuola %>
            <% end %>
          </ul>
        </div>
      <% end %>
    </div>
  <% end %>

  <%= render "ritiri/bulk_bar", scuola: @scuola %>
<% end %>
```

- [ ] **Step 1.9: Run test controller per verificare nessuna regressione**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb
```

Atteso: tutti gli 8 test passano (la vista mostra le stesse cose).

- [ ] **Step 1.10: Commit**

```bash
git add app/models/ritiro.rb test/models/ritiro_test.rb \
        app/controllers/ritiri_controller.rb \
        app/views/ritiri/show.html.erb app/views/ritiri/_lista.html.erb
git commit -m "$(cat <<'EOF'
refactor(ritiri): estrai logica vista in PORO Ritiro

Il controller#show ora istanzia Ritiro.new(scuola). Le ivar
@bolle/@righe_per_bolla/@gruppo_per_libro_e_collana sono sostituite
da @ritiro.bolle/@ritiro.righe(bolla)/@ritiro.gruppo_per(libro, collana).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Sposta `crea_documento` nel PORO

**Obiettivo:** Eliminare il service `Ritiro::CreaDocumento` portando la logica come metodo `Ritiro#crea_documento`. Risolve anche il conflitto modulo/classe per Zeitwerk.

**Files:**
- Modify: `app/models/ritiro.rb`
- Modify: `test/models/ritiro_test.rb`
- Modify: `app/controllers/ritiri_documenti_controller.rb`
- Delete: `app/services/ritiro/crea_documento.rb`
- Delete: `app/services/ritiro/` (directory vuota)
- Delete: `test/services/ritiro/crea_documento_test.rb`
- Delete: `test/services/ritiro/` (directory vuota)

- [ ] **Step 2.1: Aggiungi i test di `crea_documento` al `ritiro_test.rb`**

Aggiungi in `test/models/ritiro_test.rb`, prima del `end` finale:

```ruby
  # --- crea_documento -------------------------------------------------------

  test "crea_documento crea documento con causale, clientable e righe; chiude bolle_visione_righe" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    documento = @ritiro.crea_documento(
      righe: [riga1, riga2],
      causale: causali(:scarico_saggi),
      clientable: @scuola,
      data: Date.current
    )

    assert_equal causali(:scarico_saggi), documento.causale
    assert_equal @scuola, documento.clientable
    assert_equal 2, documento.documento_righe.count

    riga1.reload
    assert_equal "in_saggio", riga1.esito
    assert_not_nil riga1.processato_at
    assert_includes documento.documento_righe.map { |dr| dr.riga.libro_id }, riga1.libro_id
  end

  test "crea_documento raises ArgumentError quando causale è nil; nessun documento creato" do
    riga = bolla_visione_righe(:aperta)
    assert_no_difference "Documento.count" do
      assert_raises ArgumentError do
        @ritiro.crea_documento(righe: [riga], causale: nil, clientable: @scuola, data: Date.current)
      end
    end
    riga.reload
    assert_nil riga.processato_at
  end

  test "crea_documento rollback se Riga.create! fallisce a metà; nessun Documento; riga non chiusa" do
    riga1 = bolla_visione_righe(:aperta)
    riga2 = bolla_visione_righe(:aperta_due)

    call_count = 0
    original_create = Riga.method(:create!)

    Riga.singleton_class.send(:alias_method, :__orig_create_bang!, :create!)
    Riga.define_singleton_method(:create!) do |*args, **kwargs|
      call_count += 1
      raise ActiveRecord::RecordInvalid.new(Riga.new) if call_count == 2
      original_create.call(*args, **kwargs)
    end

    begin
      assert_no_difference ["Documento.count", "DocumentoRiga.count", "Riga.count"] do
        assert_raises ActiveRecord::RecordInvalid do
          @ritiro.crea_documento(
            righe: [riga1, riga2],
            causale: causali(:scarico_saggi),
            clientable: @scuola,
            data: Date.current
          )
        end
      end
    ensure
      Riga.singleton_class.send(:alias_method, :create!, :__orig_create_bang!)
      Riga.singleton_class.send(:remove_method, :__orig_create_bang!)
    end

    riga1.reload
    assert_nil riga1.processato_at, "la prima BV riga non deve risultare processata dopo rollback"
  end
```

- [ ] **Step 2.2: Run test (devono fallire — `crea_documento` non esiste)**

```bash
docker exec prova-app-1 bin/rails test test/models/ritiro_test.rb
```

Atteso: 3 errori `NoMethodError: undefined method 'crea_documento'` per `Ritiro` instance.

- [ ] **Step 2.3: Implementa `Ritiro#crea_documento`**

Modifica `app/models/ritiro.rb`. Aggiungi la costante in cima (dopo `class Ritiro`):

```ruby
class Ritiro
  CAUSALE_TO_ESITO = {
    "Scarico saggi" => :in_saggio,
    "TD01"          => :venduto_fattura,
    "Ordine Scuola" => :venduto_corrispettivi,
    "Mancante"      => :mancante
  }.freeze

  attr_reader :scuola
  # ... resto del file ...
```

E aggiungi i metodi pubblico+privati prima della sezione `private` (oppure riorganizza il file):

```ruby
  # --- comandi --------------------------------------------------------------

  def crea_documento(righe:, causale:, clientable:, data:)
    raise ArgumentError, "causale è obbligatoria" if causale.nil?

    Documento.transaction do
      documento = Current.account.documenti.create!(
        causale: causale,
        clientable: clientable,
        data_documento: data,
        numero_documento: prossimo_numero(causale),
        user: Current.user
      )
      righe.each_with_index { |riga, i| processa_riga(riga, documento, i, causale) }
      documento
    end
  end
```

E nei metodi privati aggiungi:

```ruby
  def prossimo_numero(causale)
    (Current.account.documenti.where(causale: causale).maximum(:numero_documento) || 0) + 1
  end

  def processa_riga(bv_riga, documento, idx, causale)
    riga = Riga.create!(
      libro: bv_riga.libro,
      quantita: bv_riga.quantita,
      prezzo_cents: bv_riga.libro.prezzo_in_cents
    )
    documento.documento_righe.create!(riga: riga, posizione: idx)
    bv_riga.update!(
      esito: CAUSALE_TO_ESITO.fetch(causale.causale),
      processato_at: Time.current
    )
  end
```

- [ ] **Step 2.4: Cancella il service e il suo test (libera il namespace)**

```bash
rm app/services/ritiro/crea_documento.rb
rmdir app/services/ritiro
rm test/services/ritiro/crea_documento_test.rb
rmdir test/services/ritiro
```

- [ ] **Step 2.5: Aggiorna `RitiriDocumentiController#create` per usare il PORO**

Modifica `app/controllers/ritiri_documenti_controller.rb` — sostituisci il blocco `Documento.transaction do ... end` dentro `create`:

```ruby
  def create
    if righe.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una riga." and return
    end

    righe_finali = applica_split_fascicoli(righe)
    @documento = Ritiro.new(@scuola).crea_documento(
      righe: righe_finali,
      causale: causale,
      clientable: clientable,
      data: params[:data_documento]
    )

    redirect_to scuola_ritiro_path(@scuola),
                notice: "Documento #{@documento.causale.causale} creato (#{@documento.documento_righe.count} righe)."
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to scuola_ritiro_path(@scuola), alert: "Errore: #{e.message}"
  end
```

I metodi privati `set_scuola`, `righe`, `causale`, `clientable`, `applica_split_fascicoli` restano invariati.

- [ ] **Step 2.6: Run tutti i test impattati**

```bash
docker exec prova-app-1 bin/rails test test/models/ritiro_test.rb test/controllers/ritiri_documenti_controller_test.rb test/controllers/ritiri_controller_test.rb
```

Atteso: 0 failures, 0 errors.

- [ ] **Step 2.7: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(ritiri): sposta crea_documento da service in PORO Ritiro

Elimina app/services/ritiro/crea_documento.rb (service object verbale)
e ne integra la logica come metodo Ritiro#crea_documento.
Libera il namespace Ritiro per altri usi (class Ritiro in app/models).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Namespace `Ritiri::` per documenti e bolle

**Obiettivo:** Creare il namespace `Ritiri::` con `BaseController` condiviso. Spostare `RitiriDocumentiController` → `Ritiri::DocumentiController` e `BolleVisioneDaCollaneController` → `Ritiri::BolleController`. Aggiornare routes e view.

**Files:**
- Create: `app/controllers/ritiri/base_controller.rb`
- Create: `app/controllers/ritiri/documenti_controller.rb`
- Create: `app/controllers/ritiri/bolle_controller.rb`
- Create: `test/controllers/ritiri/documenti_controller_test.rb`
- Create: `test/controllers/ritiri/bolle_controller_test.rb`
- Modify: `config/routes.rb`
- Modify: `config/initializers/inflections.rb`
- Modify: `app/views/ritiri/_crea_bolle_da_collane.html.erb`
- Delete: `app/controllers/ritiri_documenti_controller.rb`
- Delete: `app/controllers/bolle_visione_da_collane_controller.rb`
- Delete: `test/controllers/ritiri_documenti_controller_test.rb`

- [ ] **Step 3.1: Aggiungi inflection per `bolla` ↔ `bolle`**

Modifica `config/initializers/inflections.rb`. Dopo la riga `inflect.irregular 'cliente', 'clienti'` aggiungi:

```ruby
  inflect.irregular 'bolla', 'bolle'
```

(Da inserire prima delle altre `irregular`, in ordine alfabetico opzionale.)

- [ ] **Step 3.2: Riavvia container per ricaricare inflections**

```bash
docker exec prova-app-1 touch tmp/restart.txt
```

(Spring/zeitwerk ricaricheranno config; non serve restart Docker.)

- [ ] **Step 3.3: Crea `Ritiri::BaseController`**

Crea `app/controllers/ritiri/base_controller.rb`:

```ruby
class Ritiri::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end
end
```

- [ ] **Step 3.4: Crea `Ritiri::DocumentiController`**

Crea `app/controllers/ritiri/documenti_controller.rb` con il contenuto di `RitiriDocumentiController` ma:
- ereditando da `Ritiri::BaseController` (rimuove `set_scuola` privato)
- nome classe namespaced

```ruby
class Ritiri::DocumentiController < Ritiri::BaseController
  def create
    if righe.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una riga." and return
    end

    righe_finali = applica_split_fascicoli(righe)
    @documento = Ritiro.new(@scuola).crea_documento(
      righe: righe_finali,
      causale: causale,
      clientable: clientable,
      data: params[:data_documento]
    )

    redirect_to scuola_ritiro_path(@scuola),
                notice: "Documento #{@documento.causale.causale} creato (#{@documento.documento_righe.count} righe)."
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    redirect_to scuola_ritiro_path(@scuola), alert: "Errore: #{e.message}"
  end

  private

  def righe
    @righe ||= begin
      ids = Array(params[:bolla_visione_riga_ids]).reject(&:blank?)
      Current.account.bolla_visione_righe
        .where(id: ids, processato_at: nil)
        .includes(:libro)
    end
  end

  def causale
    Causale.find_by(id: params[:causale_id])
  end

  def clientable
    klass = params[:clientable_type].constantize
    klass.find(params[:clientable_id])
  end

  def applica_split_fascicoli(righe_iniziali)
    return righe_iniziali if causale&.causale != "Mancante"
    return righe_iniziali if params[:fascicoli_per_riga].blank?

    righe_iniziali.flat_map do |bv_riga|
      info = params[:fascicoli_per_riga][bv_riga.id.to_s]
      next bv_riga if info.blank?

      fascicolo_ids = Array(info[:fascicolo_ids]).reject(&:blank?)
      next bv_riga if fascicolo_ids.empty?

      fascicoli = bv_riga.libro.fascicoli.where(id: fascicolo_ids)
      esito = (info[:esito_confezione].presence || "rientrato").to_sym
      bv_riga.splitta_in_fascicoli!(fascicoli, esito_confezione: esito)
    end
  end
end
```

- [ ] **Step 3.5: Crea `Ritiri::BolleController`**

Crea `app/controllers/ritiri/bolle_controller.rb`:

```ruby
class Ritiri::BolleController < Ritiri::BaseController
  def create
    collana_ids = Array(params[:collana_ids]).reject(&:blank?)
    if collana_ids.empty?
      redirect_to scuola_ritiro_path(@scuola), alert: "Seleziona almeno una collana." and return
    end

    BollaVisione.transaction do
      collana_ids.each do |cid|
        collana = Current.account.collane.find(cid)
        bv = @scuola.bolle_visione.create!(
          collana: collana,
          data_bolla: Date.current,
          user: Current.user,
          account: Current.account,
          note: "Bolla creata in fase di ritiro"
        )
        bv.crea_righe_da_collana!
      end
    end

    redirect_to scuola_ritiro_path(@scuola),
                notice: "#{collana_ids.size} bolle create."
  end
end
```

- [ ] **Step 3.6: Aggiorna `config/routes.rb`**

Cerca la sezione esistente del ritiro (intorno alla riga 489):

```ruby
      resource :ritiro, only: [:show], controller: 'ritiri' do
        resources :documenti, only: [:create], controller: 'ritiri_documenti', as: 'documenti'
        resources :bolle_da_collane, only: [:create], controller: 'bolle_visione_da_collane'
        patch 'righe/:id/rientro', to: 'ritiri#rientro', as: 'riga_rientro'
        patch 'righe/:id/riapri',  to: 'ritiri#riapri',  as: 'riga_riapri'
      end
```

Sostituisci con:

```ruby
      resource :ritiro, only: :show
      scope :ritiro, module: :ritiri, as: :ritiro do
        resources :documenti, only: :create
        resources :bolle,     only: :create
        patch 'righe/:id/rientro', to: 'ritiri#rientro', as: :riga_rientro
        patch 'righe/:id/riapri',  to: 'ritiri#riapri',  as: :riga_riapri
      end
```

**Nota:** Le route `riga_rientro`/`riga_riapri` restano temporaneamente in `RitiriController` (verranno migrate al Task 4). Lo `scope` esterno mantiene il prefisso URL `/scuole/:scuola_id/ritiro/...` invariato.

- [ ] **Step 3.7: Aggiorna `app/views/ritiri/_crea_bolle_da_collane.html.erb`**

Cerca il path helper `scuola_ritiro_bolle_da_collane_path` e sostituiscilo con `scuola_ritiro_bolle_path`. Esempio:

```bash
docker exec prova-app-1 grep -n "bolle_da_collane" app/views/ritiri/_crea_bolle_da_collane.html.erb
```

Modifica le occorrenze. (Se il file ne ha solo 1, è una `Edit` puntuale.)

- [ ] **Step 3.8: Sposta i test di `RitiriDocumentiController`**

Sposta + rinomina:

```bash
mv test/controllers/ritiri_documenti_controller_test.rb test/controllers/ritiri/documenti_controller_test.rb
```

Modifica la classe nel test rinominato:

```ruby
class Ritiri::DocumentiControllerTest < ActionDispatch::IntegrationTest
```

I path helper `scuola_ritiro_documenti_path` e `scuola_ritiro_path` restano gli stessi (la route ha conservato gli `:as`).

- [ ] **Step 3.9: Crea `test/controllers/ritiri/bolle_controller_test.rb`**

```ruby
require "test_helper"

class Ritiri::BolleControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole, :collane

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    sign_in_as(@user, @account)
  end

  test "create con collana_ids vuoti redirige con flash di errore" do
    post scuola_ritiro_bolle_path(@scuola, account_id: @account.id), params: { collana_ids: [] }
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_match(/seleziona/i, flash[:alert])
  end

  test "create con N collane crea N bolle visione per la scuola" do
    collana = collane(:fizzy_uno)
    assert_difference -> { @scuola.bolle_visione.count } => 1 do
      post scuola_ritiro_bolle_path(@scuola, account_id: @account.id), params: { collana_ids: [collana.id] }
    end
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)
    Current.user = user
    Current.account = account
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
```

**Nota:** verifica che la fixture `collane(:fizzy_uno)` esista. Se ha nome diverso, controlla `test/fixtures/collane.yml` e adegua.

- [ ] **Step 3.10: Cancella i controller e test legacy**

```bash
rm app/controllers/ritiri_documenti_controller.rb
rm app/controllers/bolle_visione_da_collane_controller.rb
```

- [ ] **Step 3.11: Run test**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri/ test/controllers/ritiri_controller_test.rb test/models/ritiro_test.rb
```

Atteso: tutti verdi. Le rotte invariate (`scuola_ritiro_documenti_path`) garantiscono compatibilità nei test esistenti.

- [ ] **Step 3.12: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(ritiri): namespace Ritiri:: per documenti e bolle

- Ritiri::BaseController condivide auth + set_scuola
- Ritiri::DocumentiController (era RitiriDocumentiController)
- Ritiri::BolleController (era BolleVisioneDaCollaneController)
- routes via scope :ritiro, module: :ritiri
- aggiunta inflection bolla/bolle

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Unifica `rientro`/`riapri` in `Ritiri::RigheController#update`

**Obiettivo:** Sostituire le custom action `rientro`/`riapri` con un solo `update` PATCH che accetta `params[:esito]`. Mantenere `params[:return_to]` per il redirect "torna a pagina bolla" usato dal partial `_bolla_visione_riga.html.erb`.

**Files:**
- Create: `app/controllers/ritiri/righe_controller.rb`
- Create: `test/controllers/ritiri/righe_controller_test.rb`
- Modify: `app/controllers/ritiri_controller.rb` (rimuove `rientro`, `riapri`, `find_riga`)
- Modify: `config/routes.rb`
- Modify: `app/views/ritiri/_riga.html.erb`
- Modify: `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb`
- Modify: `test/controllers/ritiri_controller_test.rb` (rimuove i test di rientro/riapri spostandoli)

- [ ] **Step 4.1: Crea `Ritiri::RigheController`**

Crea `app/controllers/ritiri/righe_controller.rb`:

```ruby
class Ritiri::RigheController < Ritiri::BaseController
  def update
    riga = find_riga
    if params[:esito].present?
      riga.update!(esito: params[:esito], processato_at: Time.current)
    else
      riga.update!(esito: nil, processato_at: nil)
    end
    redirect_to redirect_target(riga)
  end

  private

  def find_riga
    Current.account.bolla_visione_righe
      .joins(:bolla_visione)
      .where(bolle_visione: { scuola_id: @scuola.id })
      .find(params[:id])
  end

  def redirect_target(riga)
    case params[:return_to]
    when "bolla" then bolla_visione_path(riga.bolla_visione)
    else scuola_ritiro_path(@scuola)
    end
  end
end
```

- [ ] **Step 4.2: Aggiungi rotta `resources :righe, only: :update`**

Modifica `config/routes.rb`. Nella sezione del Task 3 sostituisci:

```ruby
      scope :ritiro, module: :ritiri, as: :ritiro do
        resources :documenti, only: :create
        resources :bolle,     only: :create
        patch 'righe/:id/rientro', to: 'ritiri#rientro', as: :riga_rientro
        patch 'righe/:id/riapri',  to: 'ritiri#riapri',  as: :riga_riapri
      end
```

con:

```ruby
      scope :ritiro, module: :ritiri, as: :ritiro do
        resources :documenti, only: :create
        resources :bolle,     only: :create
        resources :righe,     only: :update
      end
```

- [ ] **Step 4.3: Crea `test/controllers/ritiri/righe_controller_test.rb`**

```ruby
require "test_helper"

class Ritiri::RigheControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :editori, :categorie, :libri, :scuole,
           :collane, :bolle_visione, :bolla_visione_righe

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @scuola = scuole(:scuola_fizzy)
    @riga = bolla_visione_righe(:aperta)
    sign_in_as(@user, @account)
  end

  test "update con esito=rientrato chiude la riga senza creare documento" do
    assert_no_difference -> { Documento.count } do
      patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
            params: { esito: "rientrato" }
    end
    @riga.reload
    assert_equal "rientrato", @riga.esito
    assert_not_nil @riga.processato_at
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "update con esito vuoto riapre la riga (resetta esito e processato_at)" do
    @riga.update!(esito: :rientrato, processato_at: Time.current)

    assert_no_difference ["Documento.count", "DocumentoRiga.count"] do
      patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
            params: { esito: "" }
    end
    @riga.reload
    assert_nil @riga.esito
    assert_nil @riga.processato_at
    assert_redirected_to scuola_ritiro_path(@scuola, account_id: @account.id)
  end

  test "update con return_to=bolla redirige alla pagina bolla" do
    @riga.update!(esito: :rientrato, processato_at: Time.current)

    patch scuola_ritiro_riga_path(scuola_id: @scuola.id, id: @riga.id, account_id: @account.id),
          params: { esito: "", return_to: "bolla" }

    assert_redirected_to bolla_visione_path(@riga.bolla_visione, account_id: @account.id)
  end

  private

  def sign_in_as(user, account)
    session = user.sessions.create!(account: account)
    cookies[:session_token] = sign_cookie(session.token)
    Current.user = user
    Current.account = account
  end

  def sign_cookie(value)
    key_generator = Rails.application.key_generator
    secret = key_generator.generate_key("signed cookie")
    verifier = ActiveSupport::MessageVerifier.new(secret, serializer: JSON)
    verifier.generate(value)
  end
end
```

- [ ] **Step 4.4: Run test (deve fallire al partial scope perché le rotte custom esistono ancora?)**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri/righe_controller_test.rb
```

Atteso: ora che la rotta `resources :righe, only: :update` esiste, i test devono passare.

Se fallisce per `NoMethodError: scuola_ritiro_riga_path`, verifica che le routes siano caricate (`docker exec prova-app-1 bin/rails routes | grep ritiro_riga`).

- [ ] **Step 4.5: Aggiorna `app/views/ritiri/_riga.html.erb`**

Sostituisci tutto il file:

```erb
<%= tag.li id: dom_id(riga),
    class: class_names("ritiro__riga", "list-style-none", "margin-none", "full-width", "gap-quarter",
                       "ritiro__riga--rientrato": riga.rientrato?),
    data: { bolla_visione_riga_id: riga.id } do %>
  <div class="flex align-center gap full-width">
    <% unless riga.rientrato? %>
      <%= check_box_tag "bolla_visione_riga_ids[]", riga.id, false,
            class: "ritiro__riga-check flex-item-no-shrink",
            data: { action: "change->bulk-actions#count" } %>
    <% else %>
      <span class="ritiro__riga-check-spacer flex-item-no-shrink" aria-hidden="true"></span>
    <% end %>

    <div class="flex flex-column min-width" style="flex: 1; text-align: left;">
      <strong class="overflow-ellipsis txt-small"><%= riga.libro_titolo %></strong>
      <span class="txt-x-small txt-subtle">
        <%= [riga.libro_codice_isbn, riga.libro.editore&.editore].compact.join(" · ") %>
        <% if riga.libro.fascicoli.any? %>
          &middot; <%= pluralize(riga.libro.fascicoli.size, "fasc.") %>
        <% end %>
        <% if riga.quantita > 1 %>
          &middot; <span class="badge">x<%= riga.quantita %></span>
        <% end %>
        <% if riga.rientrato? %>
          &middot; <span class="badge badge--rientrato">Rientrato</span>
        <% end %>
      </span>
    </div>

    <span class="ritiro__riga-prezzo txt-small font-weight-black flex-item-no-shrink">
      <%= number_to_currency(riga.libro.prezzo_in_cents.to_f / 100, unit: "€", format: "%n %u") %>
    </span>

    <div class="ritiro__riga-actions flex gap-quarter flex-item-no-shrink"
         data-action="click->bulk-actions#stopPropagation">
      <% if riga.rientrato? %>
        <%= button_to scuola_ritiro_riga_path(scuola_id: scuola.id, id: riga.id),
              method: :patch,
              params: { esito: "" },
              class: "btn btn--small txt-x-small",
              form: { data: { turbo_frame: "_top" } } do %>
          <%= icon_tag "refresh", size: "small" %>
          <span>Annulla rientro</span>
        <% end %>
      <% else %>
        <% if riga.libro.fascicoli.any? %>
          <%= render "ritiri/dialog_fascicoli", riga: riga %>
        <% end %>

        <%= button_to scuola_ritiro_riga_path(scuola_id: scuola.id, id: riga.id),
              method: :patch,
              params: { esito: "rientrato" },
              class: "btn btn--small txt-x-small",
              form: { data: { turbo_frame: "_top" } } do %>
          <%= icon_tag "arrow-left-from-line", size: "small" %>
          <span>Rientro</span>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

Cambi: `riga_rientro_scuola_ritiro_path` → `scuola_ritiro_riga_path` con `params: { esito: "rientrato" }`; `riga_riapri_scuola_ritiro_path` → stessa con `params: { esito: "" }`. Rimosso `return_to: "ritiro"` (default è già ritiro).

- [ ] **Step 4.6: Aggiorna `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb`**

Cerca il blocco con `riga_riapri_scuola_ritiro_path` (intorno alla riga 17) e sostituisci:

```erb
      <%= button_to scuola_ritiro_riga_path(scuola_id: riga.bolla_visione.scuola_id, id: riga.id),
            method: :patch,
            params: { esito: "", return_to: "bolla" },
            class: "btn btn--small txt-x-small flex-item-no-shrink",
            data: { turbo_confirm: "Riaprire la riga?" } do %>
        Riapri
      <% end %>
```

- [ ] **Step 4.7: Rimuovi `rientro`, `riapri`, `find_riga` da `RitiriController`**

Modifica `app/controllers/ritiri_controller.rb`. Il file dopo modifica deve essere:

```ruby
class RitiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_scuola

  def show
    @ritiro = Ritiro.new(@scuola)
  end

  private

  def set_scuola
    @scuola = Current.account.scuole.find(params[:scuola_id])
  end
end
```

Note: `build_gruppo_lookup` era usato da `show`; ora vive nel PORO. `find_riga` era usato da `rientro`/`riapri`; ora vive in `Ritiri::RigheController`.

- [ ] **Step 4.8: Rimuovi i test obsoleti da `ritiri_controller_test.rb`**

Modifica `test/controllers/ritiri_controller_test.rb`. Rimuovi questi test (sono stati spostati nel `righe_controller_test.rb` o coperti dal PORO):

- `test "rientro chiude la riga senza creare documento"` (era riga 42-51)
- `test "riapri da pagina ritiro torna in pagina ritiro"` (era riga 69-75)
- `test "riapri ripristina la riga (non tocca documenti, sono autonomi)"` (era riga 77-89)

Aggiorna anche il test esistente `test "show mostra anche le righe rientrate evidenziate (con classe modifier)"` (era riga 53-61): la riga `assert_select "form[action=?]", riga_riapri_scuola_ritiro_path(...)` non funziona più perché il path helper non esiste. Sostituisci con:

```ruby
  test "show mostra anche le righe rientrate evidenziate (con classe modifier)" do
    riga = bolla_visione_righe(:aperta)
    riga.update!(esito: :rientrato, processato_at: Time.current)

    get scuola_ritiro_path(@scuola, account_id: @account.id)
    assert_response :success
    assert_select ".ritiro__riga--rientrato[data-bolla-visione-riga-id=?]", riga.id
    assert_select "form[action=?]", scuola_ritiro_riga_path(scuola_id: @scuola.id, id: riga.id, account_id: @account.id)
  end
```

- [ ] **Step 4.9: Run test completo della zona**

```bash
docker exec prova-app-1 bin/rails test test/controllers/ritiri_controller_test.rb test/controllers/ritiri/ test/models/ritiro_test.rb
```

Atteso: tutti verdi.

- [ ] **Step 4.10: Run test bolla visione (per regressioni sul partial)**

```bash
docker exec prova-app-1 bin/rails test test/controllers/bolle_visione_controller_test.rb 2>/dev/null || echo "no test file"
```

Se il test file esiste, deve restare verde.

- [ ] **Step 4.11: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(ritiri): unifica rientro/riapri in update con params[:esito]

- Ritiri::RigheController#update con params[:esito]: presente=>rientro, vuoto=>riapri
- params[:return_to]=bolla redirige a pagina bolla (uso da _bolla_visione_riga partial)
- rimossi metodi rientro/riapri da RitiriController (resta solo show)
- routes: resources :righe, only: :update sostituisce le 2 custom PATCH
- view _riga.html.erb e _bolla_visione_riga.html.erb usano i nuovi path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Namespace `BolleVisione::` per le righe

**Obiettivo:** Spostare `BollaVisioneRigheController` → `BolleVisione::RigheController`. Creare `BolleVisione::BaseController`. `BolleVisione::PersoneController` (esistente in `app/controllers/bolle_visione/persone_controller.rb`) eredita ora da `Base`.

**Files:**
- Create: `app/controllers/bolle_visione/base_controller.rb`
- Create: `app/controllers/bolle_visione/righe_controller.rb`
- Create: `test/controllers/bolle_visione/righe_controller_test.rb` (se test legacy esiste)
- Modify: `app/controllers/bolle_visione/persone_controller.rb` (eredita da Base)
- Modify: `config/routes.rb`
- Modify: `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb` (path helpers nested)
- Delete: `app/controllers/bolla_visione_righe_controller.rb`

- [ ] **Step 5.1: Crea `BolleVisione::BaseController`**

Crea `app/controllers/bolle_visione/base_controller.rb`:

```ruby
class BolleVisione::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bolla_visione

  private

  def set_bolla_visione
    @bolla_visione = Current.account.bolle_visione.find(params[:bolla_visione_id])
  end
end
```

- [ ] **Step 5.2: Crea `BolleVisione::RigheController` (copia di `BollaVisioneRigheController`)**

Crea `app/controllers/bolle_visione/righe_controller.rb`:

```ruby
class BolleVisione::RigheController < BolleVisione::BaseController
  before_action :set_riga, only: [:update, :destroy]

  def create
    libro = Libro.find(params[:bolla_visione_riga][:libro_id])
    @riga = @bolla_visione.bolla_visione_righe.create!(
      libro: libro,
      classi_target: params[:bolla_visione_riga][:classi_target],
      account: Current.account
    )

    respond_to do |format|
      format.turbo_stream do
        scuola = @bolla_visione.scuola
        classi = scuola.classi.where(anno_corso: @riga.classi_target.to_s.split(",").map(&:strip)).order(:anno_corso, :sezione)
        render turbo_stream: [
          turbo_stream.before("bolla_visione_righe_form",
            partial: "bolla_visione_righe/bolla_visione_riga",
            locals: { riga: @riga, classi: classi, persone: scuola.persone.order(:cognome) }),
          turbo_stream_totale
        ]
      end
      format.html { redirect_to @bolla_visione }
    end
  end

  def update
    if params[:toggle_classe_id].present?
      toggle_consegna!(:classe_id, params[:toggle_classe_id])
    elsif params[:toggle_persona_id].present?
      toggle_consegna!(:persona_id, params[:toggle_persona_id])
    else
      @riga.update!(riga_params)
    end

    respond_to do |format|
      format.turbo_stream do
        scuola = @bolla_visione.scuola
        collana_libro = @bolla_visione.collana.collana_libri.find_by(libro_id: @riga.libro_id)
        targets = collana_libro&.classi_target.to_s.split(",").map(&:strip)
        classi_per_anno = scuola.classi.order(:anno_corso, :sezione).group_by(&:anno_corso)
        classi = classi_per_anno.values_at(*targets).compact.flatten
        persone = classi.any? ? Persona.docente.joins(:classi).where(classi: { id: classi.map(&:id) }).distinct.order(:cognome) : Persona.none

        render turbo_stream: [
          turbo_stream.replace(@riga,
            partial: "bolla_visione_righe/bolla_visione_riga",
            locals: { riga: @riga, classi: classi, persone: persone }),
          turbo_stream_totale
        ]
      end
      format.html { redirect_to @bolla_visione }
    end
  end

  def destroy
    @riga.destroy!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: [turbo_stream.remove(@riga), turbo_stream_totale] }
      format.html { redirect_to @bolla_visione }
    end
  end

  private

  def set_riga
    @riga = @bolla_visione.bolla_visione_righe.find(params[:id])
  end

  def riga_params
    params.require(:bolla_visione_riga).permit(:quantita, :classi_target)
  end

  def turbo_stream_totale
    totale = @bolla_visione.bolla_visione_righe.sum(:quantita)
    turbo_stream.replace("bolla_visione_totale",
      html: %(<div id="bolla_visione_totale" class="flex justify-space-between align-center margin-block-start pad-block txt-medium font-weight-black" style="border-block-start: 2px solid var(--color-ink-light);"><span>Totale copie</span><span>#{totale}</span></div>).html_safe)
  end

  def toggle_consegna!(key, value)
    consegna = @riga.consegna || {}
    current = Array(consegna[key.to_s])

    if current.include?(value)
      current.delete(value)
    else
      current << value
    end

    consegna[key.to_s] = current.compact_blank
    consegna.delete(key.to_s) if consegna[key.to_s].empty?
    @riga.update!(consegna: consegna)
  end
end
```

- [ ] **Step 5.3: Modifica `BolleVisione::PersoneController` per ereditare da `Base`**

Modifica `app/controllers/bolle_visione/persone_controller.rb` — leggi il file prima di modificarlo:

```bash
docker exec prova-app-1 cat app/controllers/bolle_visione/persone_controller.rb
```

Se la classe estende direttamente `ApplicationController` e ha un `set_bolla_visione` privato, sostituisci con:

```ruby
class BolleVisione::PersoneController < BolleVisione::BaseController
  # ... resto invariato, rimuovendo set_bolla_visione privato e before_action :set_bolla_visione
end
```

Se invece il controller esistente usa pattern diverso, fai il minimo intervento per ereditare da `Base` senza cambiare comportamento.

- [ ] **Step 5.4: Aggiorna routes per usare il modulo `bolle_visione`**

Modifica `config/routes.rb`. Cerca il blocco (intorno alla riga 372):

```ruby
    resources :bolle_visione, only: %i[index show destroy] do
      resources :bolla_visione_righe, only: %i[create update destroy]
      resource :persone, only: %i[create update], controller: 'bolle_visione/persone'
    end
```

Sostituisci con:

```ruby
    resources :bolle_visione, only: %i[index show destroy] do
      member { post :rigenera }
      scope module: :bolle_visione do
        resources :righe,   only: %i[create update destroy]
        resource  :persone, only: %i[create update]
      end
    end
```

**Nota:** `member { post :rigenera }` viene aggiunto qui anche se è coperto al Task 6 — anticipa per non lasciare il file routes incompleto. Se preferisci tenerlo separato, rimuovi questa riga e riaggiungila al Task 6.

Anche cerca eventuale rotta `post 'bolle_visione/:id/rigenera'` legacy fuori dal blocco e rimuovila se esiste.

- [ ] **Step 5.5: Sposta i test del controller riga (se esistono)**

Verifica esistenza:

```bash
ls test/controllers/bolla_visione_righe_controller_test.rb 2>/dev/null
```

Se esiste, sposta:

```bash
mkdir -p test/controllers/bolle_visione
mv test/controllers/bolla_visione_righe_controller_test.rb test/controllers/bolle_visione/righe_controller_test.rb
```

Modifica la classe nel file rinominato:

```ruby
class BolleVisione::RigheControllerTest < ActionDispatch::IntegrationTest
```

E aggiorna i path helper `bolla_visione_bolla_visione_riga_path(bv, riga)` → `bolla_visione_riga_path(bv, riga)` nei test.

Se il file non esiste, **salta questo step**.

- [ ] **Step 5.6: Aggiorna i path helper nei view di composizione**

Modifica `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb`. Cerca tutte le occorrenze di:

- `bolla_visione_bolla_visione_riga_path(riga.bolla_visione, riga)` → `bolla_visione_riga_path(riga.bolla_visione, riga)`

Le righe interessate sono ~24, ~38, ~49 (basate sul Read precedente). Verifica con grep:

```bash
docker exec prova-app-1 grep -n "bolla_visione_bolla_visione_riga_path" app/views/bolla_visione_righe/_bolla_visione_riga.html.erb
```

Sostituisci ognuna.

- [ ] **Step 5.7: Cerca altri usi del path helper legacy**

```bash
docker exec prova-app-1 grep -rn "bolla_visione_bolla_visione_riga_path" app/ test/
```

Aggiorna ogni occorrenza. Se non ce n'è nessuna, perfetto.

- [ ] **Step 5.8: Cancella `BollaVisioneRigheController`**

```bash
rm app/controllers/bolla_visione_righe_controller.rb
```

- [ ] **Step 5.9: Run test**

```bash
docker exec prova-app-1 bin/rails test test/controllers/bolle_visione/ test/controllers/bolle_visione_controller_test.rb 2>/dev/null || docker exec prova-app-1 bin/rails test test/controllers/bolle_visione/
```

Atteso: tutti verdi.

- [ ] **Step 5.10: Smoke test pieno**

```bash
docker exec prova-app-1 bin/rails test
```

Atteso: nessun fallimento. Se compaiono regressioni in test che non hai toccato, sono dovute a riferimenti legacy (path helpers) sfuggiti — investiga.

- [ ] **Step 5.11: Commit**

```bash
git add -A
git commit -m "$(cat <<'EOF'
refactor(bolle_visione): namespace BolleVisione:: per righe e persone

- BolleVisione::BaseController condivide auth + set_bolla_visione
- BolleVisione::RigheController (era BollaVisioneRigheController)
- BolleVisione::PersoneController eredita ora da Base
- routes via scope module: :bolle_visione
- aggiunta rigenera come member action (anticipo per Task 6)
- view path helpers: bolla_visione_riga_path

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Cleanup e verifica finale

**Obiettivo:** Sistemare `rigenera` come member action ufficiale, fare grep finale per riferimenti legacy, eseguire l'intera test suite.

**Files:**
- Modify: `app/controllers/bolle_visione_controller.rb` (verifica `rigenera` action)
- (eventuali) modifiche puntuali per legacy refs trovate

- [ ] **Step 6.1: Verifica routing per `rigenera`**

Se al Task 5.4 hai aggiunto `member { post :rigenera }`, verifica:

```bash
docker exec prova-app-1 bin/rails routes | grep rigenera
```

Atteso: `POST /bolle_visione/:id/rigenera ... bolle_visione#rigenera`.

Se invece non l'avevi aggiunto, fallo ora modificando `config/routes.rb`:

```ruby
    resources :bolle_visione, only: %i[index show destroy] do
      member { post :rigenera }
      # ... scope module: :bolle_visione ...
    end
```

E rimuovi eventuali rotte custom legacy per `rigenera` se ce n'erano.

- [ ] **Step 6.2: Aggiorna eventuali path helper `rigenera_*` nei view**

```bash
docker exec prova-app-1 grep -rn "rigenera" app/views/ app/javascript/
```

Cerca usi tipo `bolla_visione_rigenera_path(bv)` → ora deve essere `rigenera_bolla_visione_path(bv)`. Aggiorna.

- [ ] **Step 6.3: Grep finale per riferimenti legacy**

Esegui questi grep e verifica zero risultati (oppure fix immediato):

```bash
docker exec prova-app-1 grep -rn "BollaVisioneRigheController\|BolleVisioneDaCollaneController\|RitiriDocumentiController\|Ritiro::CreaDocumento\|riga_rientro_scuola_ritiro_path\|riga_riapri_scuola_ritiro_path\|bolla_visione_bolla_visione_riga_path\|scuola_ritiro_bolle_da_collane_path" app/ test/ config/
```

Atteso: nessun output. Se compare qualcosa, è un riferimento legacy da aggiornare.

- [ ] **Step 6.4: Run test suite completa**

```bash
docker exec prova-app-1 bin/rails test
```

Atteso: 0 failures, 0 errors.

- [ ] **Step 6.5: Smoke test manuale (opzionale ma consigliato)**

Verifica nel browser dev (`localhost:3000`):
- Apri ritiro di una scuola con bolle aperte → vedi le bolle e righe
- Click "Rientro" su una riga → riga rientrata, lista aggiornata
- Click "Annulla rientro" → riga riaperta
- "Genera Saggio" su una riga → documento creato, redirect a ritiro
- Vai in pagina bolla, click "Riapri" su riga processata → riga riaperta, redirect a pagina bolla
- Vai in scuola senza bolle aperte → form "crea bolle da collane" funziona

- [ ] **Step 6.6: Commit finale di cleanup**

Solo se ci sono modifiche dopo i grep:

```bash
git add -A
git commit -m "$(cat <<'EOF'
chore(ritiri): cleanup riferimenti legacy post-refactor

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Se non ci sono modifiche, salta il commit.

---

## Riepilogo finale

Il branch `feature/ritiro-bolle-visione` ha ora:

- 7 controller rinominati/spostati in 2 namespace (`Ritiri::`, `BolleVisione::`)
- 2 BaseController per eliminare duplicazioni
- 1 PORO `Ritiro` che assorbe il vecchio service
- 5 custom action ridotte a 1 (`Ritiri::RigheController#update` con params)
- routes Rails-CRUD pulite
- inflection per `bolla`/`bolle`
- test suite verde

**Per integrazione:** seguire la skill `superpowers-ruby:finishing-a-development-branch` (merge in main / PR / cleanup).
