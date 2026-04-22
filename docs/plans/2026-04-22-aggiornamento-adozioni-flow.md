# Aggiornamento Adozioni Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Separare import zone (bulk parallelo) da `UpdateMieAdozioniJob` (account-wide serializzato) per eliminare i deadlock in produzione, con pulsante reattivo e notifica toast quando l'aggiornamento va eseguito.

**Architecture:** Due timestamp su `accounts` (`adozioni_aggiornamento_started_at`, `adozioni_aggiornate_at`) tracciano stato. `pg_try_advisory_lock(account.id)` nel job garantisce serializzazione. Pulsante "Aggiorna adozioni" già presente viene estratto in partial reattivo via Turbo broadcast. Toast globale via canale `[user, "entries"]` a fine job. Accodamento automatico rimosso da `ImportScuolePerZonaJob`/`CleanupZonaJob`, conservato da `MandatiController`/`AssegnazioniController`.

**Tech Stack:** Rails 8.1, Sidekiq 7.2, PostgreSQL advisory locks, Turbo Streams, Minitest + fixtures, Docker (`prova-app-1`).

**Design doc:** `docs/plans/2026-04-22-aggiornamento-adozioni-flow-design.md`

---

## Pre-requisiti

- Rails commands in Docker: `docker exec prova-app-1 bin/rails ...`
- Branch corrente: `feature/multi-tenancy`
- Annotate: `docker exec prova-app-1 bundle exec annotaterb models` dopo migration

---

## Task 1: Migration e helper Account

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_adozioni_aggiornamento_to_accounts.rb`
- Modify: `app/models/account.rb`
- Test: `test/models/account_test.rb`

### Step 1.1: Generate migration

Run:
```bash
docker exec prova-app-1 bin/rails g migration AddAdozioniAggiornamentoToAccounts adozioni_aggiornamento_started_at:datetime adozioni_aggiornate_at:datetime
```

Expected: file created in `db/migrate/`.

### Step 1.2: Run migration

Run:
```bash
docker exec prova-app-1 bin/rails db:migrate
```

Expected: `accounts` ora ha le due colonne. Nessun errore.

### Step 1.3: Annotate models

Run:
```bash
docker exec prova-app-1 bundle exec annotaterb models
```

Expected: `app/models/account.rb` schema comment aggiornato.

### Step 1.4: Scrivere test failing per helper Account

Aggiungere in `test/models/account_test.rb`:

```ruby
test "aggiornamento_adozioni_in_corso? false quando mai partito" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornamento_started_at: nil, adozioni_aggiornate_at: nil)
  assert_not account.aggiornamento_adozioni_in_corso?
end

test "aggiornamento_adozioni_in_corso? true se started dopo aggiornate" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornate_at: 5.minutes.ago, adozioni_aggiornamento_started_at: 1.minute.ago)
  assert account.aggiornamento_adozioni_in_corso?
end

test "aggiornamento_adozioni_in_corso? false se aggiornate dopo started" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornamento_started_at: 5.minutes.ago, adozioni_aggiornate_at: 1.minute.ago)
  assert_not account.aggiornamento_adozioni_in_corso?
end

test "adozioni_stale? true se mai aggiornate" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornate_at: nil, adozioni_aggiornamento_started_at: nil)
  assert account.adozioni_stale?
end

test "adozioni_stale? false se in corso" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornate_at: 5.minutes.ago, adozioni_aggiornamento_started_at: 1.minute.ago)
  assert_not account.adozioni_stale?
end

test "adozioni_stale? true se una zona è stata modificata dopo l'ultimo aggiornamento" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornate_at: 1.hour.ago, adozioni_aggiornamento_started_at: 2.hours.ago)
  account.zone.first&.touch
  assert account.adozioni_stale?
end

test "zone_tutte_attive? true se tutte attive" do
  account = accounts(:default)
  account.zone.update_all(stato: "attiva")
  assert account.zone_tutte_attive?
end

test "zone_tutte_attive? false se una in importazione" do
  account = accounts(:default)
  account.zone.update_all(stato: "attiva")
  account.zone.first&.update!(stato: "importazione")
  assert_not account.zone_tutte_attive?
end
```

### Step 1.5: Run test — verifica fail

Run:
```bash
docker exec prova-app-1 bin/rails test test/models/account_test.rb
```

Expected: FAIL con `NoMethodError: undefined method 'aggiornamento_adozioni_in_corso?'`.

### Step 1.6: Implementazione minima

Aggiungere in `app/models/account.rb` (prima della chiusura di `class`):

```ruby
def aggiornamento_adozioni_in_corso?
  adozioni_aggiornamento_started_at.present? &&
    (adozioni_aggiornate_at.nil? || adozioni_aggiornate_at < adozioni_aggiornamento_started_at)
end

def adozioni_stale?
  return false if aggiornamento_adozioni_in_corso?
  return true  if adozioni_aggiornate_at.nil?

  ultima_modifica = [zone.maximum(:updated_at), mandati.maximum(:updated_at)].compact.max
  ultima_modifica.present? && ultima_modifica > adozioni_aggiornate_at
end

def zone_tutte_attive?
  zone.where.not(stato: "attiva").none?
end
```

### Step 1.7: Run test — verifica pass

Run:
```bash
docker exec prova-app-1 bin/rails test test/models/account_test.rb
```

Expected: PASS su tutti i nuovi test. Nessuna regressione.

### Step 1.8: Commit

```bash
git add db/migrate/*add_adozioni_aggiornamento_to_accounts.rb db/schema.rb app/models/account.rb test/models/account_test.rb
git commit -m "feat(accounts): add adozioni aggiornamento timestamps and helpers"
```

---

## Task 2: UpdateMieAdozioniJob con advisory lock e timestamps

**Files:**
- Modify: `app/jobs/update_mie_adozioni_job.rb`
- Test: `test/jobs/update_mie_adozioni_job_test.rb`

### Step 2.1: Scrivere test failing

Aggiungere in `test/jobs/update_mie_adozioni_job_test.rb`:

```ruby
test "setta started_at all'inizio e aggiornate_at alla fine" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornamento_started_at: nil, adozioni_aggiornate_at: nil)

  UpdateMieAdozioniJob.perform_now(account)
  account.reload

  assert_not_nil account.adozioni_aggiornamento_started_at
  assert_not_nil account.adozioni_aggiornate_at
  assert account.adozioni_aggiornate_at >= account.adozioni_aggiornamento_started_at
end

test "un secondo job concorrente esce senza toccare aggiornate_at" do
  account = accounts(:default)
  account.update_columns(adozioni_aggiornate_at: 1.hour.ago, adozioni_aggiornamento_started_at: nil)

  lock_key = Zlib.crc32("update_mie_adozioni:#{account.id}")
  ActiveRecord::Base.connection.exec_query("SELECT pg_advisory_lock(#{lock_key})")

  begin
    prima = account.adozioni_aggiornate_at
    UpdateMieAdozioniJob.perform_now(account)
    account.reload
    assert_equal prima.to_i, account.adozioni_aggiornate_at.to_i, "non deve aver aggiornato il timestamp"
  ensure
    ActiveRecord::Base.connection.exec_query("SELECT pg_advisory_unlock(#{lock_key})")
  end
end

test "rilascia il lock anche in caso di eccezione" do
  account = accounts(:default)
  lock_key = Zlib.crc32("update_mie_adozioni:#{account.id}")

  UpdateMieAdozioniJob.any_instance.stubs(:create_and_link_libri).raises("boom")

  assert_raises(RuntimeError) { UpdateMieAdozioniJob.perform_now(account) }

  acquired = ActiveRecord::Base.connection.exec_query("SELECT pg_try_advisory_lock(#{lock_key}) AS got").first["got"]
  assert acquired, "il lock deve essere stato rilasciato dopo l'eccezione"
  ActiveRecord::Base.connection.exec_query("SELECT pg_advisory_unlock(#{lock_key})")
end
```

Nota: `mocha` è già nel Gemfile (usato da altri test). Se `any_instance.stubs` non fosse disponibile, fallback con subclass di test.

### Step 2.2: Run test — verifica fail

Run:
```bash
docker exec prova-app-1 bin/rails test test/jobs/update_mie_adozioni_job_test.rb
```

Expected: FAIL (nessun timestamp aggiornato, lock non implementato).

### Step 2.3: Implementazione

Modificare `app/jobs/update_mie_adozioni_job.rb`, wrapping del body esistente:

```ruby
class UpdateMieAdozioniJob < ApplicationJob
  queue_as :default

  def perform(account, provincia: nil)
    lock_key = Zlib.crc32("update_mie_adozioni:#{account.id}")
    conn = ActiveRecord::Base.connection

    acquired = conn.exec_query("SELECT pg_try_advisory_lock(#{lock_key}) AS got").first["got"]
    unless acquired
      Rails.logger.info "[UpdateMieAdozioni] skip account #{account.id}: già in corso"
      return
    end

    account.update_columns(adozioni_aggiornamento_started_at: Time.current)
    broadcast_pulsante_stato(account)
    notifica = false

    begin
      esegui_aggiornamento(account, provincia)
      account.update_columns(adozioni_aggiornate_at: Time.current)
      notifica = true
    ensure
      conn.exec_query("SELECT pg_advisory_unlock(#{lock_key})")
      broadcast_pulsante_stato(account)
      broadcast_notifica_completamento(account) if notifica
    end
  end

  private

  def esegui_aggiornamento(account, provincia)
    # Tutto il body esistente (reset + sql_mia + sql_disdetta + create_and_link_libri
    # + update_sezioni_counts + broadcast_mandati_update + UpdateScuoleCountersJob)
    # va spostato qui dentro.
    # ...il body attuale del perform, invariato...
  end

  def broadcast_pulsante_stato(account)
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "pulsante-aggiorna-adozioni",
      partial: "accounts/configurazione/pulsante_aggiorna_adozioni",
      locals: { account: account.reload }
    )
  end

  def broadcast_notifica_completamento(account)
    account.memberships.find_each do |membership|
      Turbo::StreamsChannel.broadcast_append_to(
        [membership.user, "entries"],
        target: "toasts",
        partial: "shared/toast",
        locals: { message: "Adozioni aggiornate", level: :success }
      )
    end
  end
end
```

Nota: i due broadcast si appoggiano a partial che verranno creati ai Task 4 e 5. Fino a quel momento i broadcast falleranno silenziosamente con `ActionView::MissingTemplate` — va bene perché non bloccano il body. Però per evitare noise nei log durante il Task 2, nei test stubbiamo i broadcast.

Aggiungere in testa al test file:

```ruby
setup do
  UpdateMieAdozioniJob.any_instance.stubs(:broadcast_pulsante_stato)
  UpdateMieAdozioniJob.any_instance.stubs(:broadcast_notifica_completamento)
end
```

### Step 2.4: Run test — verifica pass

Run:
```bash
docker exec prova-app-1 bin/rails test test/jobs/update_mie_adozioni_job_test.rb
```

Expected: PASS.

### Step 2.5: Commit

```bash
git add app/jobs/update_mie_adozioni_job.rb test/jobs/update_mie_adozioni_job_test.rb
git commit -m "feat(jobs): advisory lock and timestamps on UpdateMieAdozioniJob"
```

---

## Task 3: Rimozione accodamenti automatici dai job bulk

**Files:**
- Modify: `app/jobs/import_scuole_per_zona_job.rb`
- Modify: `app/jobs/cleanup_zona_job.rb`
- Test: `test/jobs/import_scuole_per_zona_job_test.rb` (aggiornare se esiste)

### Step 3.1: Scrivere test che verifica il NON accodamento

In `test/jobs/import_scuole_per_zona_job_test.rb`:

```ruby
test "non accoda UpdateMieAdozioniJob alla fine" do
  zona = account_zone(:napoli_primaria) # o una fixture esistente

  assert_no_enqueued_jobs(only: UpdateMieAdozioniJob) do
    ImportScuolePerZonaJob.perform_now(zona)
  end
end
```

Se la fixture non esiste, crearne una minima in `test/fixtures/accounts_zone.yml`. In alternativa un setup inline che crea lo stato necessario. Se il test è pesante, accettiamo uno stub più leggero:

```ruby
test "non accoda UpdateMieAdozioniJob alla fine" do
  zona = accounts_zone(:any)
  ImportScuolePerZonaJob.any_instance.stubs(:import_codici).returns([])
  ImportScuolePerZonaJob.any_instance.stubs(:broadcast_zone_panel)
  ImportScuolePerZonaJob.any_instance.stubs(:broadcast_scuole_refresh)

  assert_no_enqueued_jobs(only: UpdateMieAdozioniJob) do
    ImportScuolePerZonaJob.perform_now(zona)
  end
end
```

Analogo in `test/jobs/cleanup_zona_job_test.rb`.

### Step 3.2: Run test — fail

Run:
```bash
docker exec prova-app-1 bin/rails test test/jobs/import_scuole_per_zona_job_test.rb test/jobs/cleanup_zona_job_test.rb
```

Expected: FAIL — `UpdateMieAdozioniJob` viene accodato.

### Step 3.3: Implementazione

In `app/jobs/import_scuole_per_zona_job.rb`:

- Rimuovere riga 22: `UpdateMieAdozioniJob.perform_later(account)`
- Aggiungere dopo il broadcast_scuole_refresh: `broadcast_pulsante_stato(account)`
- Aggiungere metodo privato analogo a quello del job update.

In `app/jobs/cleanup_zona_job.rb`:

- Rimuovere riga 44: `UpdateMieAdozioniJob.perform_later(account)`
- Aggiungere `broadcast_pulsante_stato(account)` in coda
- Aggiungere metodo privato analogo.

Il metodo `broadcast_pulsante_stato` è uguale in 3 job. Estrarre in un concern:

Create: `app/jobs/concerns/broadcasts_pulsante_aggiorna_adozioni.rb`

```ruby
module BroadcastsPulsanteAggiornaAdozioni
  extend ActiveSupport::Concern

  private

  def broadcast_pulsante_stato(account)
    Turbo::StreamsChannel.broadcast_replace_to(
      [account, "configurazione"],
      target: "pulsante-aggiorna-adozioni",
      partial: "accounts/configurazione/pulsante_aggiorna_adozioni",
      locals: { account: account.reload }
    )
  end
end
```

Include in tutti e 3 i job. Rimuove il metodo privato duplicato in `UpdateMieAdozioniJob`.

### Step 3.4: Run test — pass

Run:
```bash
docker exec prova-app-1 bin/rails test test/jobs/
```

Expected: PASS su tutti i test dei job (vecchi + nuovi).

### Step 3.5: Commit

```bash
git add app/jobs/ test/jobs/
git commit -m "refactor(jobs): remove auto-enqueue of UpdateMieAdozioniJob from bulk jobs"
```

---

## Task 4: Partial pulsante reattivo

**Files:**
- Create: `app/views/accounts/configurazione/_pulsante_aggiorna_adozioni.html.erb`
- Modify: `app/views/accounts/configurazione/show.html.erb`

### Step 4.1: Creare il partial

```erb
<%= turbo_frame_tag "pulsante-aggiorna-adozioni" do %>
  <% if account.aggiornamento_adozioni_in_corso? %>
    <button class="btn" disabled>
      <%= icon_tag "refresh" %>
      <span>Aggiornamento in corso…</span>
    </button>
  <% elsif !account.zone_tutte_attive? %>
    <button class="btn" disabled title="Attendi la fine dell'importazione zone">
      <%= icon_tag "refresh" %>
      <span>Aggiorna adozioni</span>
    </button>
  <% else %>
    <%= button_to accounts_mandati_sincronizzazione_adozioni_path,
          class: "btn margin-block-start-double #{'btn--accent' if account.adozioni_stale?}",
          style: "--btn-background: oklch(var(--lch-yellow-dark)); --btn-border-color: oklch(var(--lch-yellow-dark));" do %>
      <%= icon_tag "refresh" %>
      <span><%= account.adozioni_stale? ? "Aggiorna adozioni (modifiche in attesa)" : "Aggiorna adozioni" %></span>
    <% end %>
    <% if account.adozioni_aggiornate_at %>
      <p class="txt-x-small txt-subtle margin-block-start">
        Ultimo aggiornamento: <%= time_ago_in_words(account.adozioni_aggiornate_at) %> fa
      </p>
    <% end %>
  <% end %>
<% end %>
```

### Step 4.2: Sostituire in show.html.erb

In `app/views/accounts/configurazione/show.html.erb` sostituire le righe 29-32 (il blocco `button_to accounts_mandati_sincronizzazione_adozioni_path`) con:

```erb
<%= render "accounts/configurazione/pulsante_aggiorna_adozioni", account: Current.account %>
```

### Step 4.3: Verifica rapida con Rails server

Avviare:
```bash
bin/dev
```

Aprire `http://localhost:3002/accounts/configurazione`, verificare che il pulsante appaia correttamente nei 3 stati (forzare con console un `update_columns` per vedere "in corso" e "stale").

Expected: il pulsante si comporta come atteso, il form di submit continua a funzionare.

### Step 4.4: Commit

```bash
git add app/views/accounts/configurazione/
git commit -m "feat(accounts): reactive partial for pulsante aggiorna adozioni"
```

---

## Task 5: Toast globale

**Files:**
- Create: `app/views/shared/_toast.html.erb`
- Create: `app/javascript/controllers/toast_controller.js`
- Modify: `app/views/layouts/application.html.erb` (container `<div id="toasts">`)

### Step 5.1: Creare partial toast

```erb
<div class="toast toast--<%= level %>" data-controller="toast" data-toast-timeout-value="5000">
  <%= icon_tag level == :success ? "check" : "info" %>
  <span><%= message %></span>
</div>
```

Se non esiste già una classe `.toast` in CSS, aggiungere uno stub minimo in `app/assets/stylesheets/components/toast.css` (fallback di base; lo styling completo può arrivare dopo ispirazione da Fizzy).

### Step 5.2: Stimulus controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.element.remove(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
```

Nota: nessun import manuale in `index.js` — `eagerLoadControllersFrom` lo pesca da solo (vedi MEMORY.md).

### Step 5.3: Container nel layout

In `app/views/layouts/application.html.erb`, aggiungere prima della fine di `<body>`:

```erb
<div id="toasts" class="toasts-container"></div>
```

### Step 5.4: Verifica manuale

Dalla console del browser, broadcast manuale:

```ruby
docker exec prova-app-1 bin/rails runner '
  user = User.first
  Turbo::StreamsChannel.broadcast_append_to(
    [user, "entries"],
    target: "toasts",
    partial: "shared/toast",
    locals: { message: "test", level: :success }
  )
'
```

Expected: il toast compare per 5 secondi nella pagina corrente e poi sparisce.

### Step 5.5: Commit

```bash
git add app/views/shared/_toast.html.erb app/javascript/controllers/toast_controller.js app/views/layouts/application.html.erb app/assets/stylesheets/
git commit -m "feat(ui): global toast component via turbo broadcast"
```

---

## Task 6: Mandati raggruppati per regione

**Files:**
- Modify: `app/views/accounts/mandati/_mandati_list.html.erb`

### Step 6.1: Modificare il partial

Wrappare il loop su `province` esistente in un loop esterno su `regione`.

Nuova testa del partial:

```erb
<div id="account-editori">
    <% gradi_colonne = [["E", "Primaria"], ["M", "I Grado"], ["N", "II Grado"]] %>
    <% wildcard_mandati = mandati.select { |m| m.area.nil? } %>
    <% mandati_lookup = wildcard_mandati.index_by { |m| [m.provincia, m.editore_id, m.grado] } %>
    <% account_id = mandati.first&.account_id %>
    <% account = Account.find_by(id: account_id) %>
    <% regione_per_provincia = account ? account.zone.pluck(:provincia, :regione).to_h : {} %>
    <% mandati_per_regione = wildcard_mandati.group_by { |m| regione_per_provincia[m.provincia] || "—" } %>
    <% grand_totals = Hash.new(0) %>
    <% grand_total = 0 %>

    <% mandati_per_regione.sort_by { |r, _| r.to_s }.each do |regione, mandati_regione| %>
        <div class="zone-regione">
            <% if mandati_per_regione.size > 1 || regione.present? %>
                <strong class="divider txt-small"><%= regione %></strong>
            <% end %>

            <% province = mandati_regione.filter_map(&:provincia).uniq.sort %>
            <% province.each do |provincia| %>
                <% mandati_prov = mandati_regione.select { |m| m.provincia == provincia } %>
                <%# ...resto del corpo esistente per provincia, invariato... %>
            <% end %>
        </div>
    <% end %>
    ...
</div>
```

Il blocco interno (tabella per provincia) resta identico — solo il wrapping esterno cambia.

### Step 6.2: Verifica manuale

Aprire `/accounts/configurazione`, sezione "I miei Mandati": i mandati devono essere raggruppati per regione, con le stesse tabelle per provincia all'interno.

Expected: layout corretto, nessuna regressione su totali e azioni (disdetta, elimina).

### Step 6.3: Commit

```bash
git add app/views/accounts/mandati/_mandati_list.html.erb
git commit -m "feat(mandati): raggruppa lista mandati per regione"
```

---

## Verifica finale

### Step 7.1: Run full test suite

```bash
docker exec prova-app-1 bin/rails test
```

Expected: tutti i test passano.

### Step 7.2: Run system tests (se presenti)

```bash
docker exec prova-app-1 bin/rails test:system
```

Expected: nessuna regressione.

### Step 7.3: Sanity manuale in dev

1. Aprire `/accounts/configurazione` — pulsante mostra stato corretto
2. Modificare un mandato → pulsante diventa "stale" (evidenziato)
3. Cliccare "Aggiorna adozioni" → pulsante va a "in corso", poi torna normale con toast
4. Importare una nuova zona → pulsante resta disabilitato finché la zona non è `"attiva"`, poi diventa stale
5. Doppio click sul pulsante → advisory lock impedisce il secondo, un solo run eseguito

### Step 7.4: Merge/deploy

```bash
git push origin feature/multi-tenancy
bin/kamal deploy
```

Verifiche post-deploy:
1. `bin/kamal app exec "bin/rails runner 'puts ActiveJob::Base.queue_adapter_name'"` → `sidekiq`
2. `/sidekiq` dashboard → nessun `UpdateMieAdozioniJob` in retry su account di stress test
3. Ripulire eventuali zone stuck se ce ne sono ancora da ieri
