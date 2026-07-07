# MIUR Fase 3 — UI: risorse CRUD + show ricca Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design di riferimento: `docs/plans/2026-07-06-miur-unificazione-design.md`, Sezione 4.
> **Git (CLAUDE.md override):** NON committare automaticamente — i punti "Commit" sono checkpoint da eseguire solo su richiesta esplicita dell'utente.
> **Niente worktree:** implementare direttamente sul branch corrente (feedback utente).

**Goal:** Chiudere la Fase 3 UI del design MIUR: le 4 POST RPC-style di `controllo_adozioni` diventano risorse CRUD stile Fizzy (controller dedicati, solo azioni REST), e la show scuola diventa la pagina ricca (confronto per anno, anteprime corrente/precedente, query fuori dal controller).

**Architecture:** Un `ControlloAdozioni::BaseController` con guard admin condivisa; 4 controller figli con la sola `create` (una risorsa per azione: promozioni_massive, cambi_codice, scuole_nuove, anomalie). Il partial `_passaggio_anno` smette di costruire i path con `send` e usa una mappa esplicita in helper. La show delega a un PORO `ControlloAdozioni::Scheda` che assorbe le query oggi nel controller.

**Tech Stack:** Rails 8.1, Minitest + fixtures, Turbo (morph), CSS custom stile Fizzy. Comandi SEMPRE in Docker: `docker exec prova-app-1 bin/rails ...`.

---

## Contesto già acquisito (verificato 2026-07-07)

- **Fase 3 già fatta altrove:** merge dashboard/index in un'unica pagina (da322669), riga stato-centrica (`_riga`), barra freshness (`_freshness`), passaggio anno guidato. La separazione index/dashboard prevista dal design è **superata** dalla decisione di unificarle: NON reintrodurla.
- **Resta da fare:** 4 POST RPC (`config/routes.rb:379-382`) → controller CRUD; show ricca; `libri_per_classe` fuori da `ControlloAdozioniController` (righe 121-128).
- **Modello di stile esistente:** `app/controllers/controllo_adozioni/promozioni_controller.rb` (già REST, `new`/`create`).
- **Attenzione ai nomi route:** il blocco routes usa nomi espliciti (`as:`) per non dipendere dall'inflector con parole italiane. Fare lo stesso per le nuove risorse.
- **Il partial `_passaggio_anno`** (riga 30) costruisce i path con `send("controllo_adozioni_#{step.job}_path")` e ha un bottone "Ricalcola" hardcoded su `controllo_adozioni_ricalcola_anomalie_path` (riga 42). `step.job` ∈ `[:aggiorna_cambi_codice, :promuovi_tutte, :aggiungi_scuole_nuove]` (vedi `app/models/controllo_adozioni/passaggio_anno.rb`). NON rinominare i simboli `job` del PORO: mappare in helper.
- **Test esistenti da migrare:** `test/controllers/controllo_adozioni_controller_test.rb` ha 2 test su `ricalcola_anomalie` (admin/member, righe ~115-128) e un test drill-down che verifica `form[action*='provincia=MI']` nella sequenza.
- **Pattern test:** `fixtures :accounts, :users, :memberships, :scuole` + `sign_in_as(@user, @account)`; `fixtures :all` è DISABILITATO. Nel setup dei test controllo_adozioni si fa `Miur::Scuola.delete_all` ecc. per isolarsi dalle fixture di altre classi (vedi setup esistente).

## Fuori scope

- Track "Stat cleanup" (riscrittura ~60 stat utente + drop viste ponte).
- Fase 4 anagrafe (`import_scuole` → `miur_anagrafe_scuole`).
- Qualsiasi modifica a `promuovi_primaria!`, ai job o alla logica di dominio (Fase 2 chiusa).

---

### Task 1: `ControlloAdozioni::BaseController` + prima risorsa `promozioni_massive`

**Files:**
- Create: `app/controllers/controllo_adozioni/base_controller.rb`
- Create: `app/controllers/controllo_adozioni/promozioni_massive_controller.rb`
- Create: `test/controllers/controllo_adozioni/promozioni_massive_controller_test.rb`
- Modify: `config/routes.rb` (aggiungere la route; NON togliere ancora quella vecchia)

**Step 1: scrivi il test che fallisce**

```ruby
require "test_helper"

class ControlloAdozioni::PromozioniMassiveControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)
  end

  test "create accoda il fan-out per l'admin, scoped alla provincia" do
    assert_enqueued_with(job: PromuoviScuolePromuovibiliJob,
                         args: [@account, { provincia: "MI" }]) do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id, provincia: "MI")
    end
    assert_redirected_to controllo_adozioni_index_path(account_id: @account.id, provincia: "MI")
  end

  test "create senza provincia accoda account-wide" do
    assert_enqueued_with(job: PromuoviScuolePromuovibiliJob,
                         args: [@account, { provincia: nil }]) do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id)
    end
  end

  test "create vietata ai member" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: PromuoviScuolePromuovibiliJob do
      post controllo_adozioni_promozioni_massive_path(account_id: @account.id)
    end
    assert_response :forbidden
  end
end
```

**Step 2: verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni/promozioni_massive_controller_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'controllo_adozioni_promozioni_massive_path'`

**Step 3: route**

In `config/routes.rb`, dentro il blocco esistente `scope module: "controllo_adozioni" do` (riga ~385, quello della `resource :promozione`), aggiungere:

```ruby
      resource :promozioni_massive, only: :create, controller: "promozioni_massive",
               path: "controllo_adozioni/promozioni_massive", as: :controllo_adozioni_promozioni_massive
```

**Step 4: base controller + controller**

`app/controllers/controllo_adozioni/base_controller.rb`:

```ruby
# Base delle risorse admin del controllo adozioni (azioni massive stile Fizzy:
# ogni operazione e' la create di una risorsa). Guard admin condivisa; provincia
# opzionale per il drill-down; redirect alla pagina controllo con notice.
class ControlloAdozioni::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin

  private

  def ensure_admin
    head :forbidden unless Current.admin?
  end

  def provincia
    params[:provincia].presence
  end

  def redirect_al_controllo(notice:)
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id], provincia: provincia),
                notice: notice
  end
end
```

`app/controllers/controllo_adozioni/promozioni_massive_controller.rb`:

```ruby
# POST controllo_adozioni/promozioni_massive — promuove in blocco le scuole
# promuovibili dell'account, opzionalmente di una sola provincia. Fan-out per scuola.
class ControlloAdozioni::PromozioniMassiveController < ControlloAdozioni::BaseController
  def create
    PromuoviScuolePromuovibiliJob.perform_later(Current.account, provincia: provincia)
    redirect_al_controllo notice: "Promozione delle scuole promuovibili avviata."
  end
end
```

**Step 5: verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni/promozioni_massive_controller_test.rb`
Expected: PASS (3 test)

**Step 6: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): risorsa CRUD promozioni_massive (era promuovi_tutte)`

---

### Task 2: risorse `cambi_codice`, `scuole_nuove`, `anomalie`

**Files:**
- Create: `app/controllers/controllo_adozioni/cambi_codice_controller.rb`
- Create: `app/controllers/controllo_adozioni/scuole_nuove_controller.rb`
- Create: `app/controllers/controllo_adozioni/anomalie_controller.rb`
- Create: `test/controllers/controllo_adozioni/cambi_codice_controller_test.rb`
- Create: `test/controllers/controllo_adozioni/scuole_nuove_controller_test.rb`
- Create: `test/controllers/controllo_adozioni/anomalie_controller_test.rb`
- Modify: `config/routes.rb`

**Step 1: test (stesso schema del Task 1, un file per risorsa)**

Per ciascuna risorsa replicare i 3 test del Task 1 sostituendo job e path:

| Risorsa | Job atteso | Path helper |
|---|---|---|
| cambi_codice | `AggiornaCambiCodiceJob` | `controllo_adozioni_cambi_codice_path` |
| scuole_nuove | `AggiungiScuoleNuoveJob` | `controllo_adozioni_scuole_nuove_path` |
| anomalie | `RicalcolaAnomalieJob` | `controllo_adozioni_anomalie_path` |

ATTENZIONE `anomalie`: `RicalcolaAnomalieJob.perform_later` è **senza argomenti** (tabella globale) e il redirect è senza provincia — replicare il comportamento attuale di `ricalcola_anomalie` (controller riga 88-94): niente `args:` nell'`assert_enqueued_with` e `assert_redirected_to controllo_adozioni_index_path(account_id: @account.id)`.

**Step 2: verifica che falliscano** (route mancanti)

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni/`
Expected: FAIL sui 3 file nuovi, PASS su promozioni_massive e promozioni

**Step 3: route + controller**

Route (stesso blocco del Task 1):

```ruby
      resource :cambi_codice, only: :create, controller: "cambi_codice",
               path: "controllo_adozioni/cambi_codice", as: :controllo_adozioni_cambi_codice
      resource :scuole_nuove, only: :create, controller: "scuole_nuove",
               path: "controllo_adozioni/scuole_nuove", as: :controllo_adozioni_scuole_nuove
      resource :anomalie, only: :create, controller: "anomalie",
               path: "controllo_adozioni/anomalie", as: :controllo_adozioni_anomalie
```

Controller (stesso pattern del Task 1, ereditano da `ControlloAdozioni::BaseController`):

```ruby
# POST controllo_adozioni/cambi_codice — applica in blocco i cambi codice con
# predecessore certo (match), opzionalmente di una sola provincia.
class ControlloAdozioni::CambiCodiceController < ControlloAdozioni::BaseController
  def create
    AggiornaCambiCodiceJob.perform_later(Current.account, provincia: provincia)
    redirect_al_controllo notice: "Aggiornamento dei cambi codice con predecessore avviato."
  end
end
```

```ruby
# POST controllo_adozioni/scuole_nuove — aggiunge in blocco all'anagrafe le
# "nuove scuole" (codici nuovi senza candidati), opzionalmente di una provincia.
class ControlloAdozioni::ScuoleNuoveController < ControlloAdozioni::BaseController
  def create
    AggiungiScuoleNuoveJob.perform_later(Current.account, provincia: provincia)
    redirect_al_controllo notice: "Aggiunta delle nuove scuole avviata."
  end
end
```

```ruby
# POST controllo_adozioni/anomalie — ricostruisce da zero controllo_anomalie
# (tabella globale) dallo snapshot MIUR corrente.
class ControlloAdozioni::AnomalieController < ControlloAdozioni::BaseController
  def create
    RicalcolaAnomalieJob.perform_later
    redirect_to controllo_adozioni_index_path(account_id: params[:account_id]),
                notice: "Ricalcolo delle anomalie avviato."
  end
end
```

**Step 4: verifica che passino**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni/`
Expected: PASS

**Step 5: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): risorse CRUD cambi_codice, scuole_nuove, anomalie`

---

### Task 3: viste sui nuovi path + rimozione delle 4 azioni RPC

**Files:**
- Modify: `app/helpers/controllo_adozioni_helper.rb` (mappa step → path helper)
- Modify: `app/views/controllo_adozioni/_passaggio_anno.html.erb` (righe 30 e 41-42)
- Modify: `config/routes.rb` (rimuovere le 4 route RPC, righe 379-382)
- Modify: `app/controllers/controllo_adozioni_controller.rb` (rimuovere le 4 azioni, righe 54-94)
- Modify: `test/controllers/controllo_adozioni_controller_test.rb` (rimuovere i 2 test `ricalcola_anomalie`, ora coperti dal test del Task 2)

**Step 1: helper con mappa esplicita**

In `app/helpers/controllo_adozioni_helper.rb` aggiungere:

```ruby
  # Path della risorsa CRUD di ogni step azionabile del passaggio anno.
  # Mappa esplicita (niente send su nomi costruiti): i simboli job del PORO
  # PassaggioAnno restano stabili, le route possono evolvere.
  PASSAGGIO_STEP_PATHS = {
    aggiorna_cambi_codice: :controllo_adozioni_cambi_codice_path,
    promuovi_tutte:        :controllo_adozioni_promozioni_massive_path,
    aggiungi_scuole_nuove: :controllo_adozioni_scuole_nuove_path
  }.freeze

  def passaggio_step_path(step, account_id:, provincia:)
    public_send(PASSAGGIO_STEP_PATHS.fetch(step.job), account_id: account_id, provincia: provincia)
  end
```

**Step 2: partial**

In `_passaggio_anno.html.erb`:
- riga 30: `button_to send("controllo_adozioni_#{step.job}_path", account_id: account_id, provincia: provincia), ...` → `button_to passaggio_step_path(step, account_id: account_id, provincia: provincia), ...`
- righe 41-42: `controllo_adozioni_ricalcola_anomalie_path(account_id: account_id)` → `controllo_adozioni_anomalie_path(account_id: account_id)`

**Step 3: rimozione route + azioni + test migrati**

- `config/routes.rb`: eliminare le 4 righe `post 'controllo_adozioni/...'` (379-382).
- `ControlloAdozioniController`: eliminare `promuovi_tutte`, `aggiorna_cambi_codice`, `aggiungi_scuole_nuove`, `ricalcola_anomalie` (restano `index`, `anteprima`, `show`).
- `controllo_adozioni_controller_test.rb`: eliminare i 2 test `ricalcola_anomalie ...` (righe ~115-128).

**Step 4: verifica**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb test/controllers/controllo_adozioni/`
Expected: PASS. Se il test "drill-down provincia mostra la sequenza scoped" fallisce sul selettore `form[action*=...]`, aggiornare il selettore al nuovo path (`promozioni_massive`/`cambi_codice`/`scuole_nuove`), NON riaggiungere le route vecchie.

Poi grep di sicurezza — Run:
`grep -rn "promuovi_tutte\|aggiorna_cambi_codice_path\|aggiungi_scuole_nuove_path\|ricalcola_anomalie" app/ config/ test/`
Expected: zero occorrenze residue nelle route/viste (i nomi dei JOB `AggiornaCambiCodiceJob` ecc. ovviamente restano).

**Step 5: checkpoint commit** (solo su richiesta)
`refactor(controllo-adozioni): route RPC rimosse, il passaggio anno usa le risorse CRUD`

---

### Task 4: PORO `ControlloAdozioni::Scheda` (query della show fuori dal controller)

**Files:**
- Create: `app/models/controllo_adozioni/scheda.rb`
- Create: `test/models/controllo_adozioni/scheda_test.rb`

Il PORO assorbe tutto ciò che oggi la `show` calcola inline (controller righe 104-128) e aggiunge i dati per la pagina ricca: la scuola account corrispondente, il confronto classi/adozioni per anno, gli anni per i link anteprima.

**Step 1: scrivi il test che fallisce**

```ruby
require "test_helper"

module ControlloAdozioni
  class SchedaTest < ActiveSupport::TestCase
    fixtures :accounts, :scuole, "miur/scuole"

    setup do
      @account = accounts(:fizzy)
      @anno = Miur.anno_corrente # dalle fixture miur/scuole
    end

    def scheda(codice)
      Scheda.new(account: @account, codicescuola: codice)
    end

    test "espone anomalie raggruppate per tipo e per classe" do
      ControlloAnomalia.create!(codicescuola: "MIIC123456", tipo: "doppione",
        disciplina: "LINGUA INGLESE", denominazione: "IC Fixture", provincia: "MI",
        comune: "Milano", annocorso: "1", sezioneanno: "A", combinazione: "TN")

      s = scheda("MIIC123456")
      assert_equal({ "doppione" => 1 }, s.per_tipo)
      assert_equal 1, s.per_classe.size
      assert_equal "IC Fixture", s.denominazione
      refute s.scuola_mancante?
    end

    test "trova la scuola account dal codice ministeriale" do
      s = scheda(scuole(:scuola_fizzy).codice_ministeriale)
      assert_equal scuole(:scuola_fizzy), s.scuola
    end

    test "scuola assente dall'account: scuola nil, confronto vuoto" do
      s = scheda("ZZZZ999999")
      assert_nil s.scuola
      assert_empty s.confronto_anni
    end

    test "confronto_anni raggruppa classi e adozioni per anno scolastico" do
      scuola = scuole(:scuola_fizzy)
      classe = scuola.classi.create!(account: @account, anno_corso: "1", sezione: "Z",
        anno_scolastico: "202627", stato: "attiva", tipo_scuola: "EE")
      @account.adozioni.create!(classe: classe, codice_isbn: "123",
        anno_scolastico: "202627", codicescuola: scuola.codice_ministeriale, anno_corso: "1")

      riga = scheda(scuola.codice_ministeriale).confronto_anni
                                               .find { |r| r.anno == "202627" }
      assert riga
      assert_equal 1, riga.classi_attive
      assert_equal 1, riga.adozioni
    end

    test "anni anteprima: corrente e precedente" do
      s = scheda("MIIC123456")
      assert_equal [@anno, AnnoScolastico.new(@anno).precedente.to_s], s.anni_anteprima
    end

    test "libri_per_classe legge miur_adozioni da acquistare EE" do
      Miur::Adozione.create!(anno_scolastico: @anno, codicescuola: "MIIC123456",
        tipogradoscuola: "EE", annocorso: "1", sezioneanno: "A", combinazione: "TN",
        codiceisbn: "9880000000011", daacquist: "Si", disciplina: "ITALIANO", titolo: "Libro")

      libri = scheda("MIIC123456").libri_per_classe
      assert_equal [["1", "A", "TN"]], libri.keys
    end
  end
end
```

NB: verificare i valori reali delle fixture (`scuole(:scuola_fizzy).codice_ministeriale` è `"MIIC123456"`, le fixture `miur/scuole` fissano `Miur.anno_corrente = "202627"`) e adattare se differiscono.

**Step 2: verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/scheda_test.rb`
Expected: FAIL — `NameError: uninitialized constant ControlloAdozioni::Scheda`

**Step 3: implementazione**

`app/models/controllo_adozioni/scheda.rb`:

```ruby
module ControlloAdozioni
  # Dati della show scuola del controllo adozioni: anomalie raggruppate,
  # libri MIUR per classe, e il confronto per anno con la scuola in anagrafe
  # account (se presente). Nessuna persistenza.
  class Scheda
    RigaAnno = Struct.new(:anno, :classi_attive, :classi_archiviate, :adozioni, keyword_init: true)

    def initialize(account:, codicescuola:)
      @account = account
      @codicescuola = codicescuola
    end

    attr_reader :account, :codicescuola

    def anomalie = @anomalie ||= ControlloAnomalia.per_scuola(codicescuola)
    def per_tipo = @per_tipo ||= anomalie.group(:tipo).count

    def per_classe
      @per_classe ||= anomalie.where.not(annocorso: nil)
                              .group_by { |a| [a.annocorso, a.sezioneanno, a.combinazione] }
    end

    def scuola_mancante? = anomalie.per_tipo("scuola_mancante").exists?

    def denominazione
      @denominazione ||= anomalie.where.not(denominazione: nil).first&.denominazione ||
                         scuola&.denominazione
    end

    # La scuola in anagrafe account con questo codice (nil se non ancora acquisita).
    def scuola
      return @scuola if defined?(@scuola)

      @scuola = account.scuole.find_by(codice_ministeriale: codicescuola)
    end

    # Confronto per anno scolastico: classi attive/archiviate e adozioni della
    # scuola account, ordinato dall'anno piu' recente.
    def confronto_anni
      return [] unless scuola

      @confronto_anni ||= begin
        classi = scuola.classi.group(:anno_scolastico, :stato).count
        adozioni = scuola.adozioni.group(:anno_scolastico).count
        anni = (classi.keys.map(&:first) + adozioni.keys).compact.uniq.sort.reverse
        anni.map do |anno|
          RigaAnno.new(anno: anno,
                       classi_attive: classi.fetch([anno, "attiva"], 0),
                       classi_archiviate: classi.fetch([anno, "archiviata"], 0),
                       adozioni: adozioni.fetch(anno, 0))
        end
      end
    end

    # Anni per i link anteprima: corrente e precedente (design Sezione 4).
    def anni_anteprima
      corrente = AnnoScolastico.corrente or return []
      [corrente.to_s, corrente.precedente.to_s]
    end

    # Libri MIUR da acquistare (EE) raggruppati per classe, come @per_classe.
    # Spostato 1:1 da ControlloAdozioniController#libri_per_classe.
    def libri_per_classe
      @libri_per_classe ||= Miur::Adozione
        .per_anno(Miur.anno_corrente)
        .where(codicescuola: codicescuola, tipogradoscuola: "EE")
        .where("coalesce(daacquist, '') ILIKE 'S%'")
        .order(:annocorso, :sezioneanno, :combinazione, :disciplina, :titolo)
        .group_by { |na| [na.annocorso, na.sezioneanno, na.combinazione] }
    end
  end
end
```

**Step 4: verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/scheda_test.rb`
Expected: PASS (6 test)

**Step 5: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): Scheda, i dati della show scuola in un PORO`

---

### Task 5: show ricca (controller magro + vista con confronto e anteprime)

**Files:**
- Modify: `app/controllers/controllo_adozioni_controller.rb` (`show` + rimozione `libri_per_classe` privato)
- Modify: `app/views/controllo_adozioni/show.html.erb`
- Modify: `test/controllers/controllo_adozioni_controller_test.rb` (test show)

**Step 1: controller magro**

```ruby
  def show
    @scheda = ControlloAdozioni::Scheda.new(account: Current.account,
                                            codicescuola: params[:codicescuola])
  end
```

Rimuovere il metodo privato `libri_per_classe` (ora in `Scheda`).

**Step 2: vista**

Adattare `show.html.erb` a `@scheda` (sostituzioni meccaniche: `@denominazione` → `@scheda.denominazione`, `@codicescuola` → `@scheda.codicescuola`, `@per_tipo` → `@scheda.per_tipo`, `@per_classe` → `@scheda.per_classe`, `@scuola_mancante` → `@scheda.scuola_mancante?`, `@libri_per_classe` → `@scheda.libri_per_classe`, `@anomalie` → `@scheda.anomalie`) e aggiungere due sezioni:

1. **Fix testo legacy** (riga 22): `"Scuola assente da new_scuole (adozioni orfane)"` → `"Scuola assente dall'anagrafe MIUR corrente (adozioni orfane)"`.

2. **Barra anteprime** — sotto il link "Passaggio anno" (dopo la riga 18), i link parametrizzati per anno con label da `AnnoScolastico`:

```erb
  <p class="flex gap-half">
    <% @scheda.anni_anteprima.each do |anno| %>
      <%= link_to "Anteprima #{anno_scolastico_label(anno)}",
            controllo_adozioni_anteprima_path(@scheda.codicescuola, anno: anno, account_id: params[:account_id]),
            class: "btn btn--small" %>
    <% end %>
  </p>
```

3. **Confronto per anno** — dopo i badge anomalie (riga 30), solo se la scuola è in anagrafe:

```erb
  <% if @scheda.scuola %>
    <section class="margin-block-end">
      <h2 class="txt-medium">In anagrafe: <%= link_to @scheda.scuola.denominazione, scuola_path(@scheda.scuola, account_id: params[:account_id]) %></h2>
      <table class="libri-table txt-small">
        <thead>
          <tr>
            <th class="pad-inline">Anno</th>
            <th class="pad-inline txt-align-end">Classi attive</th>
            <th class="pad-inline txt-align-end">Archiviate</th>
            <th class="pad-inline txt-align-end">Adozioni</th>
          </tr>
        </thead>
        <tbody>
          <% @scheda.confronto_anni.each do |riga| %>
            <tr>
              <td class="pad-inline"><%= anno_scolastico_label(riga.anno) %></td>
              <td class="pad-inline txt-align-end"><%= riga.classi_attive %></td>
              <td class="pad-inline txt-align-end"><%= riga.classi_archiviate %></td>
              <td class="pad-inline txt-align-end"><%= riga.adozioni %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </section>
  <% else %>
    <p class="txt-subtle">Scuola non ancora in anagrafe.</p>
  <% end %>
```

(Adattare classi CSS a quelle già usate nel file; riusare `libri-table` per non introdurre stili nuovi.)

**Step 3: test**

Aggiornare/aggiungere in `controllo_adozioni_controller_test.rb`:

```ruby
  test "show mostra il confronto per anno se la scuola e' in anagrafe" do
    get controllo_adozioni_path(scuole(:scuola_fizzy).codice_ministeriale, account_id: @account.id)
    assert_response :success
    assert_select "h2", text: /In anagrafe/
  end

  test "show mostra i link anteprima per anno corrente e precedente" do
    Miur::Scuola.create!(codice_scuola: "MIEE99999X", anno_scolastico: "202627",
      provincia: "MI", comune: "Milano", denominazione: "PRIMARIA TEST",
      tipo_scuola: "SCUOLA PRIMARIA")
    get controllo_adozioni_path("MIEE12345", account_id: @account.id)
    assert_select "a", text: /Anteprima 2026\/27/
    assert_select "a", text: /Anteprima 2025\/26/
  end
```

(Il test esistente "show elenca le anomalie della scuola" deve continuare a passare senza modifiche.)

**Step 4: verifica**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS. Poi controllo visivo su dev (`localhost:3000`, scuola con e senza anagrafe).

**Step 5: checkpoint commit** (solo su richiesta)
`feat(controllo-adozioni): show ricca con confronto per anno e anteprime storiche`

---

### Task 6: verifica finale e chiusura Fase 3

**Step 1: suite completa**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/controllers/controllo_adozioni_controller_test.rb test/controllers/controllo_adozioni/`
Expected: tutto verde.

**Step 2: grep anti-residui**

Run: `grep -rn "ricalcola_anomalie\|promuovi_tutte" app/ config/ test/`
Expected: zero (i job `PromuoviScuolePromuovibiliJob`/`RicalcolaAnomalieJob` restano, i nomi route no).

**Step 3: aggiorna la memoria di progetto**

In `project_miur_sync_design.md`: Fase 3 UI chiusa (risorse CRUD, show ricca); restano track Stat cleanup e Fase 4 anagrafe.

**Step 4: checkpoint commit finale** (solo su richiesta)
`chore(controllo-adozioni): Fase 3 UI completata`

---

## Rischi noti

- **Path helper nel partial:** la mappa `PASSAGGIO_STEP_PATHS` deve coprire tutti gli
  `step.job` azionabili; `fetch` esplode subito in dev/test se un simbolo nuovo non è
  mappato (voluto: fail-fast, non bottone rotto in silenzio).
- **Inflector italiano:** ogni `resource` nuova dichiara `controller:`, `path:` e `as:`
  espliciti — stessa difesa già usata nel blocco route esistente.
- **Test drill-down:** verifica i form della sequenza per path; va aggiornato ai nuovi
  path, non indebolito.
- **Fixture nei test Scheda:** i valori (codici, anni) vanno verificati contro le fixture
  reali prima di assumere quelli indicati.
