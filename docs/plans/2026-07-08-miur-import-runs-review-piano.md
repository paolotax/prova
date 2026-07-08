# MIUR Import Runs — revisione pagina (account-scoped) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design di riferimento: `docs/plans/2026-07-08-miur-import-runs-review-design.md` (leggerlo prima di iniziare).
> Preferenza utente: NIENTE worktree — si lavora sul branch corrente (`main`).
> Regole progetto: commit SOLO nei punti indicati; tutti i comandi Rails in Docker (`docker exec prova-app-1 ...`); alla fine NIENTE push automatico.

**Goal:** La pagina `/:account_id/miur/import_runs` mostra solo le scuole dell'account; distingue veri cambi da spostamenti (re-keying sezioni MIUR); marca le scuole già promosse "da rettificare"; bottone unico "Applica le rettifiche" con fan-out `ReconcileAdozioniJob` sulle sole province delle promosse toccate.

**Architecture:** Un PORO `Miur::RettificheAccount` (run + account) concentra scoping, classificazione righe (via `Miur::ImportDiffRiga.classifica`), stato promossa (riuso `ControlloAdozioni::Classificazione#promossa`) e province per il fan-out. I due controller (`ImportRunsController`, `ReconcilesController`) diventano sottili e lo istanziano. Viste riscritte: lista scuole con badge, drill in linea con `<details>`.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest (fixtures accounts/users/memberships/scuole + `create!` per record miur, come i test esistenti).

---

## Fatti verificati nel codice (NON ri-verificare)

- **Stato attuale** (dalla feature diff già mergiata): controller `app/controllers/miur/import_runs_controller.rb` (index/show admin-only, oggi NON scoped), `app/controllers/miur/import_runs/reconciles_controller.rb` (oggi prende `params.require(:provincia)`, ha già `before_action :require_admin` con `head :forbidden`), viste in `app/views/miur/import_runs/`, test in `test/controllers/miur/import_runs_controller_test.rb` (4 test, andranno riscritti).
- **Routes** già a posto (`config/routes.rb`, dentro `scope '/:account_id'`): `namespace :miur { resources :import_runs, only: %i[index show] { resource :reconcile, only: :create, module: :import_runs } }`. NON toccare le routes.
- **Modelli**: `Miur::ImportRun` ha `diff_scuole`/`diff_righe` (`dependent: :delete_all`) e `diff?`; `Miur::ImportDiffScuola` ha scope `esistenti/nuove/sparite/per_provincia`; `Miur::ImportDiffRiga` ha scope `aggiunte/rimosse`. Tabelle bigint id, campi: diff_scuole(codicescuola, categoria, provincia, tipogradoscuola, righe_aggiunte, righe_rimosse), diff_righe(codicescuola, segno '+'/'-', codiceisbn, titolo, disciplina, annocorso, sezioneanno, combinazione).
- **Regola promossa** (sorgente unica, riusare MAI duplicare): `ControlloAdozioni::Classificazione.new(anno:).promossa("scuole")` ritorna un frammento SQL con named param `:anno` ("EXISTS classi attive con anno_scolastico >= :anno"). Uso col pattern di `Classificazione#conta`: `scope.where(ActiveRecord::Base.sanitize_sql([sql, anno: anno]))` (`app/models/controllo_adozioni/classificazione.rb:14-19,46-49`).
- **GOTCHA provincia**: `Adozione::Reconciler` filtra `sc.provincia = :provincia` sulle **scuole dell'account** (`app/models/adozione/reconciler.rb:86,245`) → il formato è quello di `scuole.provincia` account (sigla, es. "MI"), **NON** `miur_import_diff_scuole.provincia` (nome esteso MIUR, es. "MILANO"). Il fan-out DEVE ricavare le province dal lookup scuole account.
- `ReconcileAdozioniJob.perform(account, provincia:, anno:)`, coda `:bulk`, idempotente (`app/jobs/reconcile_adozioni_job.rb`).
- **Fixtures**: `accounts(:fizzy)`; `users(:one)` = owner di fizzy, `users(:two)` = member; `scuole(:scuola_fizzy)` = account fizzy, `codice_ministeriale: "MIIC123456"`, `provincia: "MI"`, denominazione "I.C. Leonardo da Vinci".
- **Classe** (per creare una "promossa" nei test): `Classe.create!(account:, scuola:, anno_scolastico:, stato: "attiva", anno_corso: "1", sezione: "A")` — unique index parziale su (scuola_id, anno_corso, sezione, combinazione) WHERE attiva.
- **Pattern login test**: `sign_in_as(user, account)` copiato in `test/controllers/miur/import_runs_controller_test.rb` (session + cookie firmato). Riusarlo tale e quale.
- `Current.account.scuole` esiste (usato in ControlloAdozioniController). `Current.admin?` = admin o owner.
- Helper `anno_scolastico_label("202627")` → `"2026/27"` (`app/helpers/adozioni_analytics_helper.rb`).
- Link scheda scuola: `controllo_adozioni_path(codicescuola, account_id: params[:account_id])`.
- La freshness bar con badge rettifiche è GIÀ fatta (commit f709c831) — non toccarla.
- CSS: classi disponibili `badge`, `notice notice--warning`, `txt-subtle`, `libri-table`, `ca-page` ecc. (pattern `app/views/controllo_adozioni/`). NO Tailwind.
- Nei test il DB può contenere residui di fixture di altre classi in `miur_*`: se un test dipende dall'assenza di righe, pulire nel setup (idioma `Miur::Adozione.delete_all` — vedi `ControlloAdozioniControllerTest#setup`).

## Decisioni chiuse (dal design — non rimetterle in discussione)

1. Pagina sempre account-scoped; run senza tue scuole nascosti dall'index.
2. Spostamento = ISBN presente sia tra i `+` sia tra i `-` della stessa scuola; nascosti di default, conteggio visibile, espandibili.
3. Promossa toccata → badge "da rettificare"; non promossa → informativa. Ordinamento: promosse prima, poi veri cambi desc.
4. Drill scuola in linea con `<details>/<summary>` nativi (niente Stimulus).
5. Reconcile: bottone unico, fan-out solo sulle province (formato account) delle promosse toccate, ricalcolate server-side.
6. Nessuna migration: tutto derivato a lettura.

---

### Task 1: `Miur::ImportDiffRiga.classifica` — veri cambi vs spostamenti

**Files:**
- Modify: `app/models/miur/import_diff_riga.rb`
- Test: `test/models/miur/import_diff_riga_test.rb` (create)

**Step 1: Scrivi il test fallente**

```ruby
require "test_helper"

class Miur::ImportDiffRigaTest < ActiveSupport::TestCase
  test "classifica separa aggiunte/rimosse vere dagli spostamenti (stesso isbn su entrambi i segni)" do
    righe = [
      riga(segno: "+", codiceisbn: "9781111111111", sezioneanno: "AAFM"), # spostata (isbn anche in -)
      riga(segno: "-", codiceisbn: "9781111111111", sezioneanno: "A"),    # spostata
      riga(segno: "+", codiceisbn: "9782222222222", sezioneanno: "B"),    # vera aggiunta
      riga(segno: "-", codiceisbn: "9783333333333", sezioneanno: "C")     # vera rimozione
    ]

    c = Miur::ImportDiffRiga.classifica(righe)

    assert_equal ["9782222222222"], c[:aggiunte].map(&:codiceisbn)
    assert_equal ["9783333333333"], c[:rimosse].map(&:codiceisbn)
    assert_equal %w[9781111111111 9781111111111], c[:spostate].map(&:codiceisbn).sort
  end

  test "classifica con righe vuote torna gruppi vuoti" do
    c = Miur::ImportDiffRiga.classifica([])
    assert_equal [], c[:aggiunte]
    assert_equal [], c[:rimosse]
    assert_equal [], c[:spostate]
  end

  private

  def riga(attrs)
    Miur::ImportDiffRiga.new({ codicescuola: "MIIC123456", disciplina: "ITALIANO",
                               annocorso: "1", combinazione: "X" }.merge(attrs))
  end
end
```

**Step 2: Verifica che fallisca**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_diff_riga_test.rb
```

Atteso: FAIL (`undefined method 'classifica'`).

**Step 3: Implementa** — in `app/models/miur/import_diff_riga.rb`, dentro la classe:

```ruby
  # Classifica le righe diff di UNA scuola: un ISBN presente sia tra i '+' sia
  # tra i '-' è uno "spostamento" (re-keying MIUR di sezione/classe, il libro
  # non cambia); il resto sono vere aggiunte/rimozioni. Derivata a lettura.
  def self.classifica(righe)
    aggiunti, rimossi = righe.partition { |r| r.segno == "+" }
    comuni = aggiunti.map(&:codiceisbn).to_set & rimossi.map(&:codiceisbn).to_set
    {
      aggiunte: aggiunti.reject { |r| comuni.include?(r.codiceisbn) },
      rimosse:  rimossi.reject { |r| comuni.include?(r.codiceisbn) },
      spostate: righe.select { |r| comuni.include?(r.codiceisbn) }
    }
  end
```

**Step 4: Verifica che passi**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_diff_riga_test.rb
```

Atteso: 2 runs, 0 failures.

**Step 5: Commit**

```bash
git add app/models/miur/import_diff_riga.rb test/models/miur/import_diff_riga_test.rb
git commit -m "feat(miur): ImportDiffRiga.classifica separa veri cambi da spostamenti"
```

---

### Task 2: PORO `Miur::RettificheAccount` — scoping, promosse, province fan-out

Il cuore della revisione. Concentra TUTTA la logica account-scoped così i controller
restano sottili (un oggetto istanziato, regola Sandi Metz).

**Files:**
- Create: `app/models/miur/rettifiche_account.rb`
- Test: `test/models/miur/rettifiche_account_test.rb` (create)

**Step 1: Scrivi il test fallente**

```ruby
require "test_helper"

class Miur::RettificheAccountTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    @account = accounts(:fizzy)
    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   completed_at: Time.current)
    # Scuola dell'account (fixture: MIIC123456, provincia MI) toccata dal diff
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 2, righe_rimosse: 1)
    # Scuola NON dell'account: deve sparire da ogni lettura
    @run.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente",
                             provincia: "TORINO", righe_aggiunte: 5, righe_rimosse: 5)
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9782222222222", sezioneanno: "B", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9781111111111", sezioneanno: "AAFM", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "-",
                            codiceisbn: "9781111111111", sezioneanno: "A", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "XXEE000099", segno: "+",
                            codiceisbn: "9789999999999", sezioneanno: "A", annocorso: "1")
    @rett = Miur::RettificheAccount.new(run: @run, account: @account)
  end

  test "scuole limitate a quelle dell'account" do
    assert_equal %w[MIIC123456], @rett.esistenti.map(&:codicescuola)
  end

  test "classificate espone veri cambi e spostamenti per scuola" do
    c = @rett.classificate.fetch("MIIC123456")
    assert_equal ["9782222222222"], c[:aggiunte].map(&:codiceisbn)
    assert_equal [], c[:rimosse]
    assert_equal 2, c[:spostate].size
  end

  test "promossa? e province_promosse: senza classi attive niente fan-out" do
    assert_not @rett.promossa?("MIIC123456")
    assert_equal [], @rett.province_promosse
  end

  test "promossa? e province_promosse: con classe attiva dell'anno la provincia account entra nel fan-out" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")
    rett = Miur::RettificheAccount.new(run: @run, account: @account)
    assert rett.promossa?("MIIC123456")
    # Provincia in formato ACCOUNT ("MI" dalla scuola), NON MIUR ("MILANO")
    assert_equal ["MI"], rett.province_promosse
  end

  test "run_ids torna solo i run che toccano scuole dell'account" do
    altro = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                    completed_at: Time.current)
    altro.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente")

    ids = Miur::RettificheAccount.run_ids(@account)
    assert_includes ids, @run.id
    assert_not_includes ids, altro.id
  end

  test "esistenti ordinate: promosse prima, poi veri cambi desc" do
    Scuola.create!(account: @account, denominazione: "Seconda", codice_ministeriale: "MIEE000002",
                   comune: "Milano", provincia: "MI", grado: "E", stato: "attiva")
    @run.diff_scuole.create!(codicescuola: "MIEE000002", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 9, righe_rimosse: 0)
    9.times do |i|
      @run.diff_righe.create!(codicescuola: "MIEE000002", segno: "+",
                              codiceisbn: "97800000000#{i}0", sezioneanno: "A", annocorso: "1")
    end
    # MIIC123456 promossa (1 vero cambio), MIEE000002 no (9 veri cambi):
    # la promossa vince comunque l'ordinamento.
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "2", sezione: "A")
    rett = Miur::RettificheAccount.new(run: @run, account: @account)
    assert_equal %w[MIIC123456 MIEE000002], rett.esistenti.map(&:codicescuola)
  end
end
```

**Step 2: Verifica che fallisca**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/rettifiche_account_test.rb
```

Atteso: FAIL (`uninitialized constant Miur::RettificheAccount`).

**Step 3: Implementa `app/models/miur/rettifiche_account.rb`**

```ruby
# Lettura account-scoped del diff di un import MIUR (design
# 2026-07-08-miur-import-runs-review-design.md). Il diff persistito resta
# MIUR-globale; qui si filtra alle scuole dell'account e si arricchisce con:
#   - classificazione righe (veri cambi vs spostamenti, via ImportDiffRiga.classifica)
#   - stato promossa (regola canonica ControlloAdozioni::Classificazione, mai duplicata)
#   - province per il fan-out reconcile (formato scuole ACCOUNT, es. "MI":
#     il Reconciler filtra su scuole.provincia dell'account, NON sul nome MIUR)
class Miur::RettificheAccount
  def initialize(run:, account:)
    @run = run
    @account = account
  end

  attr_reader :run, :account

  # Run (adozioni) che toccano almeno una scuola dell'account: l'index nasconde gli altri.
  def self.run_ids(account)
    codici = account.scuole.where.not(codice_ministeriale: [nil, ""])
                    .distinct.pluck(:codice_ministeriale)
    Miur::ImportDiffScuola.where(codicescuola: codici).distinct.pluck(:import_run_id)
  end

  def scuole_toccate
    @scuole_toccate ||= run.diff_scuole.where(codicescuola: codici_account).to_a
  end

  # Rollup "esistente" ordinati: promosse prima (sono le "da rettificare"),
  # poi veri cambi desc — in cima ciò che richiede un'azione.
  def esistenti
    @esistenti ||= scuole_toccate.select { |s| s.categoria == "esistente" }
      .sort_by { |s| [promossa?(s.codicescuola) ? 0 : 1, -veri_cambi(s.codicescuola)] }
  end

  def nuove   = scuole_toccate.select { |s| s.categoria == "nuova" }
  def sparite = scuole_toccate.select { |s| s.categoria == "sparita" }

  # {codicescuola => {aggiunte:, rimosse:, spostate:}} per le scuole toccate.
  def classificate
    @classificate ||= run.diff_righe.where(codicescuola: scuole_toccate.map(&:codicescuola))
      .order(:annocorso, :sezioneanno, :disciplina)
      .group_by(&:codicescuola)
      .transform_values { |righe| Miur::ImportDiffRiga.classifica(righe) }
  end

  def veri_cambi(codice)
    c = classificate[codice]
    c ? c[:aggiunte].size + c[:rimosse].size : 0
  end

  def spostamenti(codice)
    classificate[codice]&.fetch(:spostate)&.size || 0
  end

  # Totali per la card di sintesi.
  def totale_aggiunte    = classificate.values.sum { |c| c[:aggiunte].size }
  def totale_rimosse     = classificate.values.sum { |c| c[:rimosse].size }
  def totale_spostamenti = classificate.values.sum { |c| c[:spostate].size }

  def promossa?(codice) = promosse.include?(codice)

  # Province (formato account, es. "MI") delle scuole PROMOSSE toccate:
  # il fan-out reconcile copre solo queste.
  def province_promosse
    scuole_account.values_at(*promosse.to_a).compact
                  .map(&:provincia).compact.uniq.sort
  end

  # {codice_ministeriale => Scuola} per denominazione/provincia/grado/link scheda.
  def scuole_account
    @scuole_account ||= account.scuole
      .where(codice_ministeriale: scuole_toccate.map(&:codicescuola))
      .index_by(&:codice_ministeriale)
  end

  private

  def codici_account
    @codici_account ||= account.scuole.where.not(codice_ministeriale: [nil, ""])
                               .distinct.pluck(:codice_ministeriale)
  end

  # Codici delle scuole toccate già promosse (classi attive dell'anno del run).
  # Unica query, regola canonica di Classificazione (pattern di #conta).
  def promosse
    @promosse ||= begin
      cl = ControlloAdozioni::Classificazione.new(anno: run.anno_scolastico)
      account.scuole
             .where(codice_ministeriale: scuole_toccate.map(&:codicescuola))
             .where(ActiveRecord::Base.sanitize_sql([cl.promossa("scuole"), anno: run.anno_scolastico]))
             .pluck(:codice_ministeriale).to_set
    end
  end
end
```

**Step 4: Verifica che passi**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/rettifiche_account_test.rb
```

Atteso: 6 runs, 0 failures. Se il test `run_ids` pesca run sporchi di altre classi
di test, pulire nel setup con `Miur::ImportRun.delete_all` +
`Miur::ImportDiffScuola.delete_all` + `Miur::ImportDiffRiga.delete_all` (dentro la
transazione di test, rollbackato).

**Step 5: Commit**

```bash
git add app/models/miur/rettifiche_account.rb test/models/miur/rettifiche_account_test.rb
git commit -m "feat(miur): Miur::RettificheAccount — lettura account-scoped del diff import"
```

---

### Task 3: Controller index/show sottili sul PORO + test riscritti

**Files:**
- Modify: `app/controllers/miur/import_runs_controller.rb` (riscrittura completa)
- Modify: `test/controllers/miur/import_runs_controller_test.rb` (riscrittura completa)

**Step 1: Riscrivi il test** (sostituisci l'intero file; mantieni gli helper
`sign_in_as`/`sign_cookie` ESATTAMENTE come sono nel file attuale):

```ruby
require "test_helper"

class Miur::ImportRunsControllerTest < ActionDispatch::IntegrationTest
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    @admin = users(:one)
    @member = users(:two)
    sign_in_as(@admin, @account)

    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   righe_totali: 100, completed_at: Time.current)
    # Scuola dell'account (fixture MIIC123456) + una estranea che NON deve apparire
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 1, righe_rimosse: 1)
    @run.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente",
                             provincia: "TORINO", righe_aggiunte: 5, righe_rimosse: 5)
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9782222222222", titolo: "NUOVO LIBRO",
                            disciplina: "ITALIANO", annocorso: "1", sezioneanno: "B")
    @run.diff_righe.create!(codicescuola: "XXEE000099", segno: "+",
                            codiceisbn: "9789999999999", titolo: "LIBRO ESTRANEO",
                            disciplina: "STORIA", annocorso: "1", sezioneanno: "A")
  end

  test "index elenca solo i run che toccano scuole dell'account" do
    senza_mie = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                        righe_totali: 50, completed_at: 1.day.ago)
    senza_mie.diff_scuole.create!(codicescuola: "XXEE000099", categoria: "esistente")

    get miur_import_runs_path(account_id: @account.id)
    assert_response :success
    assert_match "2026/27", @response.body
    assert_select "a[href*='#{miur_import_run_path(@run, account_id: @account.id)}']"
    assert_select "a[href*='#{miur_import_run_path(senza_mie, account_id: @account.id)}']", count: 0
  end

  test "show mostra solo le scuole dell'account con denominazione" do
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "I.C. Leonardo da Vinci", @response.body
    assert_no_match "XXEE000099", @response.body
    assert_no_match "LIBRO ESTRANEO", @response.body
  end

  test "show marca da rettificare le scuole promosse" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "da rettificare", @response.body
  end

  test "show senza scuole promosse non mostra il badge" do
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_no_match "da rettificare", @response.body
  end

  test "show con spostamenti li segnala collassati" do
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "+",
                            codiceisbn: "9781111111111", sezioneanno: "AAFM", annocorso: "1")
    @run.diff_righe.create!(codicescuola: "MIIC123456", segno: "-",
                            codiceisbn: "9781111111111", sezioneanno: "A", annocorso: "1")
    get miur_import_run_path(@run, account_id: @account.id)
    assert_response :success
    assert_match "spostament", @response.body   # "spostamenti"/"spostamento"
    assert_select "details"                      # drill collassato
  end

  test "member non admin viene respinto" do
    sign_in_as(@member, @account)
    get miur_import_runs_path(account_id: @account.id)
    assert_redirected_to root_path(account_id: @account.id)
  end

  private

  # <<< COPIARE sign_in_as e sign_cookie dal file esistente, invariati >>>
end
```

**Step 2: Verifica che fallisca** (il body contiene ancora XXEE000099)

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/import_runs_controller_test.rb
```

**Step 3: Riscrivi il controller** `app/controllers/miur/import_runs_controller.rb`:

```ruby
# Storia degli import MIUR letta nel contesto dell'account: solo le scuole
# dell'account, veri cambi vs spostamenti, promosse marcate "da rettificare"
# (design 2026-07-08-miur-import-runs-review-design.md). Admin-only.
class Miur::ImportRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @runs = Miur::ImportRun.adozioni
      .where(id: Miur::RettificheAccount.run_ids(Current.account))
      .order(completed_at: :desc).limit(50)

    codici = Current.account.scuole.where.not(codice_ministeriale: [nil, ""])
                    .distinct.pluck(:codice_ministeriale)
    scoped = Miur::ImportDiffScuola.where(import_run_id: @runs.map(&:id), codicescuola: codici)
    @scuole_per_run  = scoped.group(:import_run_id).count
    @aggiunte_per_run = scoped.group(:import_run_id).sum(:righe_aggiunte)
    @rimosse_per_run  = scoped.group(:import_run_id).sum(:righe_rimosse)
  end

  def show
    @run = Miur::ImportRun.adozioni.find(params[:id])
    @rettifiche = Miur::RettificheAccount.new(run: @run, account: Current.account)
  end

  private

  def require_admin
    redirect_to root_path, alert: "Solo per amministratori" unless Current.admin?
  end
end
```

NOTA: spariscono `@riepilogo_province`, `@provincia`, `@scuola_focus`, `sostituzioni` —
il vecchio drill via querystring è sostituito dal drill in linea (Task 5).

**Step 4: Viste minime per far passare i test** — anticipa qui la sostanza di Task 5
(le viste vanno comunque riscritte: fallo una volta sola, vedi Task 5 per il
contenuto completo di `index.html.erb` e `show.html.erb`).

**Step 5: Verifica che passino**

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/import_runs_controller_test.rb
```

Atteso: 6 runs, 0 failures.

**Step 6: Commit** (insieme alle viste, vedi Task 5 — un solo commit congiunto va bene:
`git add app/controllers/miur app/views/miur test/controllers/miur` +
`git commit -m "feat(miur): pagina import_runs account-scoped con badge da-rettificare e drill in linea"`)

---

### Task 4: Reconcile fan-out sulle province delle promosse

**Files:**
- Modify: `app/controllers/miur/import_runs/reconciles_controller.rb`
- Test: `test/controllers/miur/import_runs/reconciles_controller_test.rb` (create)

**Step 1: Scrivi il test fallente**

```ruby
require "test_helper"

class Miur::ImportRuns::ReconcilesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  fixtures :accounts, :users, :memberships, :scuole

  setup do
    @account = accounts(:fizzy)
    sign_in_as(users(:one), @account)

    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   completed_at: Time.current)
    @run.diff_scuole.create!(codicescuola: "MIIC123456", categoria: "esistente",
                             provincia: "MILANO", righe_aggiunte: 1, righe_rimosse: 0)
  end

  test "accoda un job per provincia (formato account) delle promosse toccate" do
    Classe.create!(account: @account, scuola: scuole(:scuola_fizzy),
                   anno_scolastico: "202627", stato: "attiva", anno_corso: "1", sezione: "A")

    assert_enqueued_with(job: ReconcileAdozioniJob,
                         args: [@account, { provincia: "MI", anno: "202627" }]) do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_redirected_to miur_import_run_path(@run, account_id: @account.id)
  end

  test "senza promosse toccate non accoda nulla" do
    assert_no_enqueued_jobs only: ReconcileAdozioniJob do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_redirected_to miur_import_run_path(@run, account_id: @account.id)
  end

  test "member non admin respinto senza accodare" do
    sign_in_as(users(:two), @account)
    assert_no_enqueued_jobs only: ReconcileAdozioniJob do
      post miur_import_run_reconcile_path(@run, account_id: @account.id)
    end
    assert_response :forbidden
  end

  private

  # <<< COPIARE sign_in_as e sign_cookie dal test import_runs, invariati >>>
end
```

**Step 2: Verifica che fallisca** (il controller attuale esige `params.require(:provincia)` → 400)

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/import_runs/reconciles_controller_test.rb
```

**Step 3: Riscrivi il controller** `app/controllers/miur/import_runs/reconciles_controller.rb`:

```ruby
# Bottone "Applica le rettifiche": convenienza manuale (MAI automatico).
# Fan-out di ReconcileAdozioniJob sulle sole province (formato scuole account)
# delle scuole PROMOSSE toccate dal run — ricalcolate server-side, mai da params.
# Le protezioni sul lavoro utente sono nel Reconciler (DO NOTHING + orfane protette).
class Miur::ImportRuns::ReconcilesController < ApplicationController
  before_action :authenticate_user!
  # Prima di qualunque find: un member non deve poter sondare l'esistenza dei run.
  before_action :require_admin

  def create
    run = Miur::ImportRun.adozioni.find(params[:import_run_id])
    province = Miur::RettificheAccount.new(run: run, account: Current.account).province_promosse

    province.each do |provincia|
      ReconcileAdozioniJob.perform_later(Current.account, provincia: provincia,
                                         anno: run.anno_scolastico)
    end
    notice = province.any? ? "Reconcile accodato per: #{province.join(', ')}"
                           : "Nessuna scuola promossa da rettificare"
    redirect_to miur_import_run_path(run), notice: notice
  end

  private

  def require_admin
    head :forbidden unless Current.admin?
  end
end
```

**Step 4: Verifica che passino**

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/import_runs/reconciles_controller_test.rb
```

Atteso: 3 runs, 0 failures. Se `assert_enqueued_with` fallisce sul formato args
(GlobalID dell'account), stampare `enqueued_jobs.first[:args]` e adattare l'assert
(gli args serializzati usano GlobalID per i record) — in alternativa usare il blocco
con `assert_enqueued_jobs 1, only: ReconcileAdozioniJob` + check manuale di provincia.

**Step 5: Commit**

```bash
git add app/controllers/miur/import_runs test/controllers/miur/import_runs
git commit -m "feat(miur): reconcile fan-out sulle province delle scuole promosse toccate"
```

---

### Task 5: Viste — lista con badge, drill in linea, spostamenti collassati

(Se già anticipate al Task 3 per far passare i test, qui si rifiniscono e si committa.)

**Files:**
- Modify: `app/views/miur/import_runs/index.html.erb` (riscrittura)
- Modify: `app/views/miur/import_runs/show.html.erb` (riscrittura)
- Modify (se serve): `app/assets/stylesheets/analytics.css` (solo se manca una classe badge warning)

**Step 0: Verifica classi CSS disponibili** — `grep -rn "badge--warning\|badge--warn" app/assets/stylesheets/` ;
se assente, aggiungi in `analytics.css` accanto alle regole `.ca-freshness__*`:

```css
  .badge--rettifica {
    background: oklch(var(--lch-yellow-dark));
    color: var(--color-canvas);
  }
```

**Step 1: `index.html.erb`** (sostituzione completa):

```erb
<% @page_title = "Import MIUR" %>

<% content_for :header do %>
  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis">Rettifiche import MIUR</span>
  </h1>
<% end %>

<div class="ca-page">
  <p class="txt-subtle">Import che toccano le tue scuole (diff MIUR-vs-MIUR per import).</p>

  <% if @runs.empty? %>
    <p class="notice">Nessun import ha toccato le tue scuole.</p>
  <% else %>
    <table class="libri-table txt-small">
      <thead>
        <tr>
          <th class="pad-inline">Data</th>
          <th class="pad-inline">Anno</th>
          <th class="pad-inline txt-align-end">Tue scuole</th>
          <th class="pad-inline txt-align-end">+ righe</th>
          <th class="pad-inline txt-align-end">− righe</th>
        </tr>
      </thead>
      <tbody>
        <% @runs.each do |run| %>
          <tr>
            <td class="pad-inline">
              <%= link_to l(run.completed_at, format: :short),
                    miur_import_run_path(run, account_id: params[:account_id]) %>
            </td>
            <td class="pad-inline"><%= anno_scolastico_label(run.anno_scolastico) %></td>
            <td class="pad-inline txt-align-end"><%= @scuole_per_run[run.id].to_i %></td>
            <td class="pad-inline txt-align-end"><%= @aggiunte_per_run[run.id].to_i %></td>
            <td class="pad-inline txt-align-end"><%= @rimosse_per_run[run.id].to_i %></td>
          </tr>
        <% end %>
      </tbody>
    </table>
  <% end %>
</div>
```

**Step 2: `show.html.erb`** (sostituzione completa; `r = @rettifiche`):

```erb
<% @page_title = "Import MIUR #{anno_scolastico_label(@run.anno_scolastico)}" %>

<% content_for :header do %>
  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis">
      Rettifiche del <%= l(@run.completed_at, format: :short) if @run.completed_at %>
    </span>
  </h1>
<% end %>

<% r = @rettifiche %>
<div class="ca-page">
  <p class="txt-subtle">
    <%= link_to "← Tutti gli import", miur_import_runs_path(account_id: params[:account_id]) %>
    · <%= anno_scolastico_label(@run.anno_scolastico) %>
  </p>

  <% if r.scuole_toccate.empty? %>
    <p class="notice">Questo import non tocca nessuna delle tue scuole.</p>
  <% else %>
    <%# Card sintesi %>
    <div class="badges">
      <span class="badge"><%= r.esistenti.size %> scuole con rettifiche</span>
      <span class="badge">+<%= r.totale_aggiunte %> / −<%= r.totale_rimosse %> veri cambi</span>
      <% if r.totale_spostamenti.positive? %>
        <span class="badge txt-subtle"><%= r.totale_spostamenti %> spostamenti</span>
      <% end %>
      <% if r.nuove.any? %><span class="badge"><%= r.nuove.size %> nuove</span><% end %>
      <% if r.sparite.any? %><span class="badge"><%= r.sparite.size %> sparite</span><% end %>
    </div>

    <% if r.province_promosse.any? %>
      <p>
        <%= button_to "Applica le rettifiche (#{r.province_promosse.join(', ')})",
              miur_import_run_reconcile_path(@run, account_id: params[:account_id]),
              method: :post, class: "btn" %>
      </p>
    <% end %>

    <%# Lista scuole: promosse prima (da rettificare), poi veri cambi desc %>
    <% r.esistenti.each do |s| %>
      <% scuola = r.scuole_account[s.codicescuola] %>
      <% c = r.classificate[s.codicescuola] %>
      <details class="margin-block-end">
        <summary>
          <strong><%= scuola&.denominazione || s.codicescuola %></strong>
          · <%= scuola&.provincia || s.provincia %>
          <% if r.promossa?(s.codicescuola) %>
            <span class="badge badge--rettifica">da rettificare</span>
          <% end %>
          — +<%= c ? c[:aggiunte].size : 0 %> / −<%= c ? c[:rimosse].size : 0 %>
          <% if r.spostamenti(s.codicescuola).positive? %>
            <span class="txt-subtle">· <%= r.spostamenti(s.codicescuola) %> spostamenti</span>
          <% end %>
          <% unless r.promossa?(s.codicescuola) %>
            <span class="txt-subtle">(non promossa: si allineerà alla promozione)</span>
          <% end %>
        </summary>

        <% if scuola %>
          <p><%= link_to "Apri scheda", controllo_adozioni_path(s.codicescuola, account_id: params[:account_id]),
                   class: "btn btn--small" %></p>
        <% end %>

        <% if c %>
          <% if c[:aggiunte].any? %>
            <h3 class="txt-medium">Aggiunti</h3>
            <ul>
              <% c[:aggiunte].each do |riga| %>
                <li>+ <%= riga.annocorso %><%= riga.sezioneanno %> · <%= riga.disciplina %>
                    · <%= riga.codiceisbn %> · <%= riga.titolo %></li>
              <% end %>
            </ul>
          <% end %>
          <% if c[:rimosse].any? %>
            <h3 class="txt-medium">Rimossi</h3>
            <ul>
              <% c[:rimosse].each do |riga| %>
                <li>− <%= riga.annocorso %><%= riga.sezioneanno %> · <%= riga.disciplina %>
                    · <%= riga.codiceisbn %> · <%= riga.titolo %></li>
              <% end %>
            </ul>
          <% end %>
          <% if c[:spostate].any? %>
            <details>
              <summary class="txt-subtle">
                <%= c[:spostate].size %> spostamenti (stesso libro, altra classe/sezione)
              </summary>
              <ul class="txt-subtle">
                <% c[:spostate].each do |riga| %>
                  <li><%= riga.segno %> <%= riga.annocorso %><%= riga.sezioneanno %>
                      · <%= riga.disciplina %> · <%= riga.codiceisbn %> · <%= riga.titolo %></li>
                <% end %>
              </ul>
            </details>
          <% end %>
        <% end %>
      </details>
    <% end %>

    <% if r.nuove.any? %>
      <section class="margin-block-end">
        <h2 class="txt-medium">Tue scuole nuove nel MIUR</h2>
        <p class="txt-subtle">
          <%= r.nuove.size %> scuole comparse ora.
          <%= link_to "Promuovile dal Controllo adozioni →",
                controllo_adozioni_index_path(account_id: params[:account_id]) %>
        </p>
      </section>
    <% end %>

    <% if r.sparite.any? %>
      <section class="margin-block-end">
        <h2 class="txt-medium">Tue scuole sparite dal MIUR (possibili cambi codice)</h2>
        <div class="badges">
          <% r.sparite.each do |s| %>
            <% scuola = r.scuole_account[s.codicescuola] %>
            <span class="badge"><%= scuola&.denominazione || s.codicescuola %></span>
          <% end %>
        </div>
      </section>
    <% end %>
  <% end %>
</div>
```

**Step 3: Tutti i test controller + modelli miur**

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/ test/models/miur/
```

Atteso: tutti verdi.

**Step 4: Check visivo in dev** — il run reale #8 esiste già con 734 diff_scuole;
l'account dev ne interseca alcune (es. "Production Tax": 4 scuole, "ptax": 292).
Aprire `/{account_id}/miur/import_runs` e verificare: run visibile, show con sole
scuole account, badge sulle promosse, drill `<details>` funzionante, spostamenti
collassati. Se le pagine sono ok, procedere.

**Step 5: Commit** (se non già fatto al Task 3):

```bash
git add app/controllers/miur app/views/miur app/assets/stylesheets/analytics.css test/controllers/miur
git commit -m "feat(miur): pagina import_runs account-scoped con badge da-rettificare e drill in linea"
```

---

### Task 6: Suite completa + STOP

**Step 1: Tutta la suite**

```bash
docker exec prova-app-1 bin/rails test
```

Atteso: verde (849+ runs, 0 failures; 2 skip pre-esistenti sono normali).

**Step 2: STOP — riepilogo per l'utente.** Mostrare `git log --oneline` dei commit
creati. NIENTE push (lo decide l'utente). Segnalare esplicitamente:
- eventuali deviazioni dal piano;
- che il vecchio drill via querystring (`?codicescuola=`, `?provincia=`) è stato
  rimosso: eventuali link/bookmark a quelle URL cadono sulla show normale (ok).

---

## Fuori scope (ribadito — NON implementare)

- Vista globale non-scoped o toggle admin.
- Persistenza della classificazione spostamenti.
- Veri-cambi/spostamenti nell'index (solo nella show).
- Re-reconcile automatico.
- Modifiche a routes, migrations, mail scraper, freshness bar (già fatta).
