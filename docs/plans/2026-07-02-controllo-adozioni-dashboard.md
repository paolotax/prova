# Controllo Adozioni — fork admin/agente + dashboard aggregata (Sezione 4)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** L'admin di un account editore apre `controllo_adozioni` e vede una dashboard di soli aggregati SQL (per provincia + agenti), non 24k righe; la vista operativa attuale resta per i member e come drill-down per provincia.

**Architecture:** Nuovo PORO `ControlloAdozioni::Dashboard` (una query GROUP BY sulle scuole dell'account con EXISTS su new_adozioni/new_scuole/classi/controllo_anomalie). Fork in `ControlloAdozioniController#index`: admin senza `provincia` → `render :dashboard`; altrimenti vista operativa (`Panoramica`) scoped. Le azioni bulk (`promuovi_tutte`, `aggiorna_cambi_codice`) diventano scoped per provincia.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest + fixtures. Comandi in Docker: `docker exec prova-app-1 bin/rails ...`

**Contesto misurato (dev, account bacherini, 24.325 scuole):** `Panoramica#gruppi` 2,2s + `conteggi_stati` 1,0s + `cambi_codice` 2,0s ≈ 5s di calcolo prima del render. La vista è quella sbagliata per l'admin: serve un'aggregata.

**Nota working tree:** `app/views/controllo_adozioni/index.html.erb` ha una modifica non committata che rimuove il blocco lista paginata — va **ripristinato** (Task 3): la lista serve a member e drill-down; per l'admin nazionale semplicemente non si arriva più a quel template.

---

### Task 1: `ControlloAdozioni::Dashboard` (PORO, TDD)

**Files:**
- Test: `test/models/controllo_adozioni/dashboard_test.rb`
- Create: `app/models/controllo_adozioni/dashboard.rb`

Semantica identica a `Panoramica` (stessi criteri di `Riga`), ma aggregata per provincia:
- universo = scuole account con `codice_ministeriale` presente e "con adozioni" (`adozioni_count > 0 OR EXISTS new_adozioni`)
- `promosse` = EXISTS classi attive con `anno_scolastico >= anno` (anno = `NewScuola.maximum(:anno_scolastico)`)
- `da_promuovere` = in `new_scuole(anno)` AND in `new_adozioni` EE AND NOT promossa
- `mancanti_miur` = NOT EXISTS `new_adozioni`
- `anomalie` = EXISTS `controllo_anomalie`
- `agenti` = memberships member con conteggio `membership_scuole` + `non_assegnate_count`

**Step 1: test fallente**

```ruby
require "test_helper"

module ControlloAdozioni
  class DashboardTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @account = accounts(:fizzy)
      @anno = "202627"
      # Scuola sintetica isolata (provincia XX) come in reconciler_test
      @scuola = @account.scuole.create!(
        codice_ministeriale: "XXEE00001A", denominazione: "Primaria Dash",
        provincia: "XX", comune: "TESTOPOLI", grado: "E", tipo_scuola: "SCUOLA PRIMARIA",
        adozioni_count: 3)
      NewScuola.create!(codice_scuola: "XXEE00001A", anno_scolastico: @anno,
        provincia: "XX", comune: "TESTOPOLI", denominazione: "PRIMARIA DASH",
        tipo_scuola: "SCUOLA PRIMARIA", regione: "TESTLANDIA", area_geografica: "TEST",
        codice_istituto_riferimento: "XXIC000001")
      NewAdozione.create!(codicescuola: "XXEE00001A", anno_scolastico: @anno,
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", daacquist: "Si", disciplina: "LIBRO DELLA PRIMA CLASSE")
    end

    test "riga provincia conta scuole, da_promuovere e mancanti" do
      righe = Dashboard.new(account: @account).righe
      xx = righe.find { |r| r.provincia == "XX" }

      assert_equal 1, xx.scuole
      assert_equal 1, xx.da_promuovere, "in new_scuole+new_adozioni EE senza classi attive all'anno"
      assert_equal 0, xx.promosse
      assert_equal 0, xx.mancanti_miur
    end

    test "scuola con classi attive all'anno corrente è promossa, non da promuovere" do
      @account.classi.create!(scuola: @scuola, anno_scolastico: @anno, anno_corso: "1",
        sezione: "A", stato: "attiva", codice_ministeriale_origine: "XXEE00001A",
        classe_origine: "1", sezione_origine: "A")

      xx = Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
      assert_equal 1, xx.promosse
      assert_equal 0, xx.da_promuovere
    end

    test "scuola con adozioni assente dal MIUR conta come mancante" do
      NewAdozione.where(codicescuola: "XXEE00001A").delete_all
      NewScuola.where(codice_scuola: "XXEE00001A").delete_all

      xx = Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
      assert_equal 1, xx.mancanti_miur
      assert_equal 0, xx.da_promuovere
    end

    test "scuola senza adozioni e fuori MIUR non entra nel conteggio" do
      @scuola.update_columns(adozioni_count: 0)
      NewAdozione.where(codicescuola: "XXEE00001A").delete_all

      righe = Dashboard.new(account: @account).righe
      assert_nil righe.find { |r| r.provincia == "XX" }
    end

    test "anomalie conteggiate per provincia" do
      ControlloAnomalia.create!(codicescuola: "XXEE00001A", tipo: "doppione")

      xx = Dashboard.new(account: @account).righe.find { |r| r.provincia == "XX" }
      assert_equal 1, xx.anomalie
    end

    test "totali somma le righe" do
      d = Dashboard.new(account: @account)
      assert_equal d.righe.sum(&:scuole), d.totali[:scuole]
      assert_equal d.righe.sum(&:da_promuovere), d.totali[:da_promuovere]
    end

    test "agenti con conteggio scuole assegnate e non assegnate" do
      bob = memberships(:bob_fizzy)
      bob.membership_scuole.create!(scuola: @scuola)

      d = Dashboard.new(account: @account)
      agente = d.agenti.find { |a| a.membership == bob }
      assert_equal 1, agente.scuole_count
      assert_equal @account.scuole.count - 1, d.non_assegnate_count
    end
  end
end
```

**Step 2:** `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/dashboard_test.rb` → FAIL (`uninitialized constant ControlloAdozioni::Dashboard`).

**Step 3: implementazione**

```ruby
module ControlloAdozioni
  # Dashboard admin di controllo_adozioni: soli aggregati SQL per provincia
  # (stessi criteri delle righe di Panoramica) + stato assegnazione agenti.
  # Niente materializzazione delle scuole: una query GROUP BY per le righe.
  class Dashboard
    Riga = Struct.new(:provincia, :scuole, :promosse, :da_promuovere, :mancanti_miur, :anomalie,
                      keyword_init: true)
    Agente = Struct.new(:membership, :scuole_count, keyword_init: true)

    def initialize(account:)
      @account = account
    end

    attr_reader :account

    def anno = @anno ||= NewScuola.maximum(:anno_scolastico)

    def righe
      @righe ||= ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql([sql_righe, account_id: account.id, anno: anno.to_s])
      ).map do |r|
        Riga.new(provincia: r["provincia"], scuole: r["scuole"].to_i, promosse: r["promosse"].to_i,
                 da_promuovere: r["da_promuovere"].to_i, mancanti_miur: r["mancanti_miur"].to_i,
                 anomalie: r["anomalie"].to_i)
      end
    end

    def totali
      @totali ||= %i[scuole promosse da_promuovere mancanti_miur anomalie]
        .index_with { |k| righe.sum(&k) }
    end

    def agenti
      @agenti ||= begin
        counts = Accounts::MembershipScuola.joins(:membership)
          .where(memberships: { account_id: account.id }).group(:membership_id).count
        account.memberships.role_member.includes(:user).map do |m|
          Agente.new(membership: m, scuole_count: counts[m.id].to_i)
        end.sort_by { |a| -a.scuole_count }
      end
    end

    def non_assegnate_count
      @non_assegnate_count ||= account.scuole.where.not(
        id: Accounts::MembershipScuola.joins(:membership)
              .where(memberships: { account_id: account.id }).select(:scuola_id)
      ).count
    end

    private

    # promosse/da_promuovere hanno senso solo con uno snapshot MIUR presente.
    def sql_righe
      promossa = anno.present? ? <<~SQL.strip : "FALSE"
        EXISTS (SELECT 1 FROM classi c WHERE c.scuola_id = sc.id
                AND c.stato = 'attiva' AND c.anno_scolastico >= :anno)
      SQL
      promuovibile = anno.present? ? <<~SQL.strip : "FALSE"
        EXISTS (SELECT 1 FROM new_scuole ns WHERE ns.codice_scuola = sc.codice_ministeriale
                AND ns.anno_scolastico = :anno)
        AND EXISTS (SELECT 1 FROM new_adozioni nae WHERE nae.codicescuola = sc.codice_ministeriale
                    AND nae.tipogradoscuola = 'EE')
        AND NOT EXISTS (SELECT 1 FROM classi c2 WHERE c2.scuola_id = sc.id
                        AND c2.stato = 'attiva' AND c2.anno_scolastico >= :anno)
      SQL

      <<~SQL
        SELECT provincia,
               COUNT(*)                                AS scuole,
               COUNT(*) FILTER (WHERE promossa)        AS promosse,
               COUNT(*) FILTER (WHERE promuovibile)    AS da_promuovere,
               COUNT(*) FILTER (WHERE NOT nel_miur)    AS mancanti_miur,
               COUNT(*) FILTER (WHERE con_anomalie)    AS anomalie
        FROM (
          SELECT sc.provincia,
                 EXISTS (SELECT 1 FROM new_adozioni na
                         WHERE na.codicescuola = sc.codice_ministeriale)          AS nel_miur,
                 EXISTS (SELECT 1 FROM controllo_anomalie ca
                         WHERE ca.codicescuola = sc.codice_ministeriale)          AS con_anomalie,
                 #{promossa}     AS promossa,
                 #{promuovibile} AS promuovibile
          FROM scuole sc
          WHERE sc.account_id = :account_id
            AND COALESCE(sc.codice_ministeriale, '') <> ''
            AND (sc.adozioni_count > 0 OR EXISTS (
                   SELECT 1 FROM new_adozioni nac
                   WHERE nac.codicescuola = sc.codice_ministeriale))
        ) s
        GROUP BY provincia
        ORDER BY provincia
      SQL
    end
  end
end
```

Nota: verificare il nome dello scope enum (`role_member` vs `where(role: :member)`) in `Accounts::Membership` — enum `role` senza prefix ⇒ scope è `Accounts::Membership.member`; in tal caso usare `account.memberships.member`.

**Step 4:** run test → PASS.
**Step 5:** commit `feat(controllo-adozioni): dashboard aggregata per provincia (PORO)`.

### Task 2: fork nel controller + drill-down `provincia` (TDD)

**Files:**
- Test: `test/controllers/controllo_adozioni_controller_test.rb` (aggiorna: il test "index mostra la panoramica paginata" ora vale per il drill-down; nuovi test per dashboard e member)
- Modify: `app/controllers/controllo_adozioni_controller.rb`
- Modify: `app/models/controllo_adozioni/panoramica.rb` (kwarg `provincia:` per scopare `build_cambi_codice` su `account.zone.where(provincia:)`)

**Step 1: test fallenti** (users(:one)=owner fizzy, users(:two)=member fizzy)

```ruby
test "index admin senza provincia mostra la dashboard aggregata" do
  get controllo_adozioni_index_path(account_id: @account.id)
  assert_response :success
  assert_match "Per provincia", @response.body
  assert_no_match "controllo_adozioni-pagination-list", @response.body
end

test "index admin con provincia mostra la panoramica paginata" do
  get controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
  assert_response :success
  assert_match "I.C. Leonardo da Vinci", @response.body
  assert_match "controllo_adozioni-pagination-list", @response.body
  assert_no_match "Scuola Primaria Bologna Centro", @response.body
end

test "index member mostra la vista operativa senza dashboard" do
  sign_in_as(users(:two), @account)
  get controllo_adozioni_index_path(account_id: @account.id)
  assert_response :success
  assert_no_match "Per provincia", @response.body
end
```

(Adattare il vecchio test "index mostra la panoramica paginata": aggiungere `provincia:` o riusarlo come test drill-down. Verifica preliminare: `Scuola Primaria Bologna Centro` deve avere adozioni/new_adozioni nelle fixture per comparire — altrimenti scegliere un'altra scuola per l'assert negativo.)

**Step 2:** run → FAIL.

**Step 3: controller**

```ruby
def index
  @filtro = params[:filtro].presence
  @provincia = params[:provincia].presence

  if Current.admin? && @provincia.blank?
    @dashboard = ControlloAdozioni::Dashboard.new(account: Current.account)
    return render :dashboard
  end

  scuole = Current.scuole
  scuole = scuole.where(provincia: @provincia) if @provincia
  @panoramica = ControlloAdozioni::Panoramica.new(account: Current.account, scuole: scuole,
                                                  provincia: @provincia)

  gruppi = @panoramica.gruppi_filtrati(@filtro)
  @total_count = gruppi.sum { |g| g[:scuole].size }
  @gruppi_per_leader = gruppi.index_by { |g| (g[:direzione] || g[:scuole].first).id }

  leader_ids = @gruppi_per_leader.keys
  set_page_and_extract_portion_from Current.scuole.where(id: leader_ids).in_order_of(:id, leader_ids)
end
```

**Panoramica:** `def initialize(account:, scuole: nil, provincia: nil)` con `@provincia = provincia`; in `build_cambi_codice` sostituire `account.zone.order(:provincia, :grado)` con:

```ruby
zone = account.zone.order(:provincia, :grado)
zone = zone.where(provincia: @provincia) if @provincia
zone.each do |zona|
```

**Step 4:** run controller test + `test/models/controllo_adozioni/` → PASS.
**Step 5:** commit `feat(controllo-adozioni): fork admin/agente con drill-down per provincia`.

### Task 3: vista dashboard + ripristino lista operativa

**Files:**
- Create: `app/views/controllo_adozioni/dashboard.html.erb`
- Modify: `app/views/controllo_adozioni/index.html.erb` (ripristina il blocco lista da git; aggiungi link "← Tutte le province" per admin in drill-down)
- Modify: `app/views/controllo_adozioni/_filtri.html.erb` (propaga `provincia` nei link filtro)
- Modify: `app/views/controllo_adozioni/_cambi_codice.html.erb`, `_promuovi_tutte.html.erb` (propaga `provincia` nelle POST)

**Step 1: ripristina lista** — `git checkout -- app/views/controllo_adozioni/index.html.erb`, poi aggiungi in testa al `.stats-container` (solo drill-down admin):

```erb
<% if Current.admin? && @provincia.present? %>
  <p class="margin-block-end-half">
    <%= link_to controllo_adozioni_index_path(account_id: params[:account_id]), class: "btn btn--small" do %>
      ← Tutte le province
    <% end %>
    <span class="txt-medium margin-inline-start-half"><%= @provincia %></span>
  </p>
<% end %>
```

e passa `provincia: @provincia` ai partial `filtri`/`cambi_codice`/`promuovi_tutte` (nuovo local, default nil con `local_assigns`).

**Step 2: dashboard.html.erb** (stile Fizzy: tabella semplice, niente card per scuola). Ogni conteggio linka il drill-down col filtro corrispondente.

```erb
<% @page_title = "Controllo adozioni" %>

<% content_for :header do %>
  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis">Controllo adozioni</span>
  </h1>
<% end %>

<%= turbo_stream_from Current.account, "controllo_adozioni" %>

<div class="stats-container">
  <% totali = @dashboard.totali %>
  <p class="txt-subtle txt-small margin-block-end-half">
    Snapshot MIUR <%= @dashboard.anno %> ·
    <%= totali[:scuole] %> scuole con adozioni in <%= @dashboard.righe.size %> province
  </p>

  <section class="margin-block-end">
    <h2 class="txt-medium">Per provincia</h2>
    <table class="table">
      <thead>
        <tr>
          <th>Provincia</th><th>Scuole</th><th>Promosse</th>
          <th>Da promuovere</th><th>Mancanti MIUR</th><th>Anomalie</th>
        </tr>
      </thead>
      <tbody>
        <% @dashboard.righe.each do |r| %>
          <tr>
            <td><%= link_to r.provincia, controllo_adozioni_index_path(provincia: r.provincia, account_id: params[:account_id]) %></td>
            <td><%= r.scuole %></td>
            <td><%= link_to_if r.promosse.positive?, r.promosse,
                  controllo_adozioni_index_path(provincia: r.provincia, filtro: "promosse", account_id: params[:account_id]) %></td>
            <td><%= link_to_if r.da_promuovere.positive?, r.da_promuovere,
                  controllo_adozioni_index_path(provincia: r.provincia, filtro: "da_promuovere", account_id: params[:account_id]) %></td>
            <td><%= link_to_if r.mancanti_miur.positive?, r.mancanti_miur,
                  controllo_adozioni_index_path(provincia: r.provincia, filtro: "mancanti_miur", account_id: params[:account_id]) %></td>
            <td><%= link_to_if r.anomalie.positive?, r.anomalie,
                  controllo_adozioni_index_path(provincia: r.provincia, filtro: "anomalie", account_id: params[:account_id]) %></td>
          </tr>
        <% end %>
      </tbody>
      <tfoot>
        <tr class="txt-medium">
          <td>Totale</td>
          <td><%= totali[:scuole] %></td><td><%= totali[:promosse] %></td>
          <td><%= totali[:da_promuovere] %></td><td><%= totali[:mancanti_miur] %></td>
          <td><%= totali[:anomalie] %></td>
        </tr>
      </tfoot>
    </table>
  </section>

  <section class="margin-block-end">
    <h2 class="txt-medium">Agenti</h2>
    <% if @dashboard.agenti.any? %>
      <table class="table">
        <thead><tr><th>Agente</th><th>Scuole assegnate</th></tr></thead>
        <tbody>
          <% @dashboard.agenti.each do |a| %>
            <tr><td><%= a.membership.user.name %></td><td><%= a.scuole_count %></td></tr>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="txt-subtle">Nessun agente nell'account.</p>
    <% end %>
    <p class="txt-subtle txt-small"><%= @dashboard.non_assegnate_count %> scuole non assegnate.</p>
  </section>
</div>
```

Verifica classi CSS esistenti (`table`, `stats-container`) contro Fizzy/`app/assets` — adattare se `table` non esiste (guardare come sono fatte le tabelle in `stats/` o usare la classe usata lì). Verificare `membership.user.name` (o `full_name`/`nome`).

**Step 3:** smoke test manuale in dev su bacherini: `/controllo_adozioni` admin < 1s, drill-down provincia ok, filtri ok.
**Step 4:** run suite controller+models.
**Step 5:** commit `feat(controllo-adozioni): vista dashboard admin per provincia`.

### Task 4: azioni bulk scoped per provincia (TDD)

**Files:**
- Test: `test/jobs/promuovi_scuole_promuovibili_job_test.rb` (se esiste — altrimenti crearlo minimale), test controller per il redirect con provincia
- Modify: `app/jobs/promuovi_scuole_promuovibili_job.rb`, `app/jobs/aggiorna_cambi_codice_job.rb`, controller actions

**Step 1: test** — job con `provincia:` promuove solo le scuole di quella provincia (seed sintetico "XX" + una seconda provincia "YY"; assert su job accodati `ScuolaPromuoviClassiJob` solo per XX).

**Step 2: implementazione**

- `PromuoviScuolePromuovibiliJob#perform(account, provincia: nil)`: `scope = account.scuole; scope = scope.where(provincia: provincia) if provincia` e usare `scope` per `codici`/`max_anno`/`find_each` (i pluck/group interni restano su `scope`).
- `AggiornaCambiCodiceJob#perform(account, provincia: nil)`: `Panoramica.new(account: account, scuole: provincia ? account.scuole.where(provincia: provincia) : nil, provincia: provincia)`.
- Controller: `promuovi_tutte`/`aggiorna_cambi_codice` passano `provincia: params[:provincia].presence` al job e la mantengono nel redirect. I partial (Task 3) la mandano già nella POST.

**Step 3:** run test → PASS.
**Step 4:** commit `feat(controllo-adozioni): promozione e cambi codice bulk scoped per provincia`.

### Task 5: verifica finale

1. Suite completa: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/controllers/controllo_adozioni_controller_test.rb test/jobs`
2. Benchmark dashboard su bacherini (`Dashboard#righe` atteso ≤ ~0,5s vs ~5s attuali).
3. Aggiornare `docs/plans/2026-07-02-editore-reconcile-assegnazione-design.md`: Sezione 4 → fatta (nota: assegnazione agenti = Sezione 3, pending).
4. Push (commit già fatti per task).

## Fuori scope (deliberato)

- Sezione 3 (strumento di assegnazione agenti): la dashboard mostra solo i conteggi.
- Rimozione di `PromuoviScuolePromuovibiliJob` nazionale: l'azione resta ma non è più raggiungibile dalla UI admin nazionale (solo drill-down per provincia).
- Conteggio "cambi codice" nella dashboard nazionale: visibile solo nel drill-down (dove è scoped e veloce).
