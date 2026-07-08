# MIUR Import Diff — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.
> Design di riferimento: `docs/plans/2026-07-08-miur-import-diff-design.md` (leggerlo prima di iniziare).
> Preferenza utente: NIENTE worktree — si lavora sul branch corrente (`main`).
> Regola progetto: commit SOLO nei punti indicati dal piano; tutti i comandi Rails girano in Docker (`docker exec prova-app-1 ...`).

**Goal:** Ad ogni `miur:importa_adozioni` persistere un diff MIUR-vs-MIUR (staging vs partizione vecchia), mostrarlo in una pagina standalone con drill-down e segnalarlo nella mail dello scraper; applicazione delle rettifiche manuale via bottone "Ri-reconcilia provincia".

**Architecture:** Un PORO `Miur::ImportDiff` calcola il diff pre-swap con `EXCEPT` sulla class-key dentro TEMP tables (stessa connessione del task rake), poi lo persiste post-swap legato a `Miur::ImportRun` su due tabelle: rollup per scuola (`miur_import_diff_scuole`, 3 categorie) e dettaglio riga (`miur_import_diff_righe`, solo scuole esistenti). UI: `Miur::ImportRunsController` (index/show) dentro l'account scope, admin-only, linkata dalla freshness.

**Tech Stack:** Rails 8.1, PostgreSQL (partizioni, TEMP tables, EXCEPT), Minitest (no fixtures per miur: `create!` come `test/tasks/miur_cambia_religione_test.rb`).

---

## Fatti verificati nel codice (non ri-verificare)

- `miur_import_runs` è **bigint id** (no UUID): `db/migrate/20260706103351_create_miur_tables.rb:49`. Le nuove tabelle `miur_import_diff_*` seguono lo stesso stile.
- Il task `miur:importa_adozioni` (`lib/tasks/miur.rake:37-216`): staging `miur_adozioni_stg`, dedup ROW_NUMBER (2b), tripwire (2c), indici+ANALYZE (3), swap in transazione (4, ~riga 188), `Miur::ImportRun.create!` DOPO lo swap (~riga 206). Il diff si calcola tra il passo 3 e il passo 4; si persiste dopo la `create!` del run.
- Class-key = `(codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina)` (stesso set dell'unique index `*_classe`, `miur.rake:174`).
- `Miur::ImportRun` ha scope `.adozioni` / `.scuole` (`app/models/miur/import_run.rb`).
- Lo scraper (`app/services/miur/adozioni_scraper.rb:190-239`) invoca il task, poi `attach_esiti_to_run`; la mail parte da `ScrapingNotificationJob` → `ScrapingMailer.scraping_completed` (view: `app/views/scraping_mailer/scraping_completed.html.erb`).
- Freshness: `app/views/controllo_adozioni/_freshness.html.erb` legge `Miur::ImportRun.adozioni.order(:completed_at).last`.
- Routes: tutto ciò che è account-scoped vive in `scope '/:account_id'` (`config/routes.rb:87`); `controllo_adozioni` è lì (~riga 376). La nuova pagina va nello stesso scope.
- Guardia admin: `Current.admin?` (idioma in `ControlloAdozioniController#index`).
- Test rake: pattern in `test/tasks/miur_cambia_religione_test.rb` (`Rails.application.load_tasks`, `Miur.stubs(:anno_corrente)`, `Miur::Adozione.create!`). Mocha disponibile.
- `ReconcileAdozioniJob.perform(account, provincia:, anno:)` — `app/jobs/reconcile_adozioni_job.rb`, coda `:bulk`, idempotente.
- Provincia di una scuola MIUR: `miur_scuole.provincia` (nome esteso, affidabile) via `codice_scuola`, filtrando `anno_scolastico`.

## Decisioni chiuse in fase di piano (dal design che le lasciava aperte)

1. **Due tabelle figlie, niente JSONB**: il rollup per provincia si fa con `GROUP BY` su `miur_import_diff_scuole` (queryable, piccola).
2. **Primo import dell'anno** (partizione vecchia inesistente): il diff si **salta** del tutto — risolve il problema-dimensione del big-bang senza soglie.
3. **Cap di sicurezza sul dettaglio**: se le righe di dettaglio superano 200.000 (import anomalo), si salvano solo i rollup e si logga il salto (mai cap silenzioso).
4. **Diff non-fatale**: ogni errore nel calcolo/persistenza del diff viene loggato ma NON blocca l'import (il diff è osservabilità, lo swap è il lavoro critico).
5. **Bottone "Ri-reconcilia"**: accoda `ReconcileAdozioniJob` per `Current.account` (la pagina vive nel contesto account; altri account rifanno il giro dal proprio contesto).
6. **"Sostituzioni da verificare"**: derivate a lettura (stessa classe+disciplina con sia `+` che `-`), nessuna persistenza dedicata.

---

### Task 1: Migration — tabelle `miur_import_diff_scuole` e `miur_import_diff_righe`

**Files:**
- Create: `db/migrate/<timestamp>_create_miur_import_diffs.rb` (genera con il comando sotto)

**Step 1: Genera la migration**

```bash
docker exec prova-app-1 bin/rails generate migration CreateMiurImportDiffs
```

**Step 2: Scrivi la migration** (sovrascrivi il file generato)

```ruby
class CreateMiurImportDiffs < ActiveRecord::Migration[8.1]
  # Diff MIUR-vs-MIUR per import (design 2026-07-08-miur-import-diff-design.md).
  # Stile miur_*: bigint id, nessuna FK fisica (import_run_id è un riferimento
  # logico a miur_import_runs, come altrove nel dominio miur).
  def change
    # Rollup per scuola toccata: una riga per (run, codicescuola).
    # categoria: esistente | nuova | sparita — derivata dal solo confronto MIUR.
    create_table :miur_import_diff_scuole do |t|
      t.bigint  :import_run_id, null: false
      t.string  :codicescuola, null: false
      t.string  :categoria, null: false
      t.string  :provincia          # da miur_scuole; NULL se il codice non è in anagrafe
      t.string  :tipogradoscuola
      t.integer :righe_aggiunte, null: false, default: 0
      t.integer :righe_rimosse, null: false, default: 0
      t.datetime :created_at, null: false
      t.index [:import_run_id, :provincia]
      t.index [:import_run_id, :categoria]
    end

    # Dettaglio riga SOLO per le scuole "esistente" (le rettifiche vere).
    # segno: '+' aggiunta, '-' rimossa. titolo denormalizzato per la UI
    # (la partizione vecchia sparisce con lo swap: qui è l'unica copia).
    create_table :miur_import_diff_righe do |t|
      t.bigint :import_run_id, null: false
      t.string :codicescuola, null: false
      t.string :segno, null: false, limit: 1
      t.string :codiceisbn
      t.string :titolo
      t.string :disciplina
      t.string :annocorso
      t.string :sezioneanno
      t.string :combinazione
      t.datetime :created_at, null: false
      t.index [:import_run_id, :codicescuola]
    end
  end
end
```

Nota: niente `updated_at` (righe write-once); `t.datetime :created_at` esplicito al posto di `t.timestamps`.

**Step 3: Migra e verifica**

```bash
docker exec prova-app-1 bin/rails db:migrate
docker exec prova-app-1 bin/rails runner 'puts ActiveRecord::Base.connection.tables.grep(/diff/).inspect'
```

Atteso: `["miur_import_diff_righe", "miur_import_diff_scuole"]`

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat(miur): tabelle miur_import_diff_scuole/righe per il diff di import"
```

---

### Task 2: Modelli `Miur::ImportDiffScuola`, `Miur::ImportDiffRiga` + associazioni su `ImportRun`

**Files:**
- Create: `app/models/miur/import_diff_scuola.rb`
- Create: `app/models/miur/import_diff_riga.rb`
- Modify: `app/models/miur/import_run.rb`
- Test: `test/models/miur/import_run_test.rb` (create)

**Step 1: Scrivi il test fallente**

```ruby
require "test_helper"

class Miur::ImportRunTest < ActiveSupport::TestCase
  test "diff_scuole e diff_righe sono agganciate al run e si distruggono con lui" do
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627")
    run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "esistente",
                            provincia: "MODENA", righe_aggiunte: 2, righe_rimosse: 1)
    run.diff_righe.create!(codicescuola: "MOEE000001", segno: "+", codiceisbn: "9780000000001")

    assert_equal 1, run.diff_scuole.count
    assert_equal 1, run.diff_righe.count

    run.destroy
    assert_equal 0, Miur::ImportDiffScuola.count
    assert_equal 0, Miur::ImportDiffRiga.count
  end

  test "diff? è vero solo se ci sono scuole toccate" do
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627")
    assert_not run.diff?
    run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "nuova")
    assert run.diff?
  end
end
```

**Step 2: Verifica che fallisca**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_run_test.rb
```

Atteso: FAIL (`undefined method 'diff_scuole'`).

**Step 3: Implementa**

`app/models/miur/import_diff_scuola.rb`:

```ruby
# Rollup per scuola toccata da un import MIUR (vedi Miur::ImportDiff).
# categoria: esistente (rettifiche, ha dettaglio righe) | nuova | sparita.
class Miur::ImportDiffScuola < ApplicationRecord
  self.table_name = "miur_import_diff_scuole"

  belongs_to :import_run, class_name: "Miur::ImportRun"

  scope :esistenti, -> { where(categoria: "esistente") }
  scope :nuove,     -> { where(categoria: "nuova") }
  scope :sparite,   -> { where(categoria: "sparita") }
  scope :per_provincia, ->(provincia) { provincia.present? ? where(provincia: provincia) : all }
end
```

`app/models/miur/import_diff_riga.rb`:

```ruby
# Dettaglio riga del diff import MIUR, solo per scuole "esistente".
# segno '+' = adozione aggiunta dal MIUR, '-' = rimossa.
class Miur::ImportDiffRiga < ApplicationRecord
  self.table_name = "miur_import_diff_righe"

  belongs_to :import_run, class_name: "Miur::ImportRun"

  scope :aggiunte, -> { where(segno: "+") }
  scope :rimosse,  -> { where(segno: "-") }
end
```

In `app/models/miur/import_run.rb` aggiungi dentro la classe:

```ruby
  has_many :diff_scuole, class_name: "Miur::ImportDiffScuola",
           foreign_key: :import_run_id, dependent: :delete_all
  has_many :diff_righe, class_name: "Miur::ImportDiffRiga",
           foreign_key: :import_run_id, dependent: :delete_all

  def diff? = diff_scuole.exists?
```

**Step 4: Verifica che passi**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_run_test.rb
```

Atteso: 2 runs, 0 failures.

**Step 5: Annota e committa**

```bash
docker exec prova-app-1 bundle exec annotaterb models
git add app/models/miur test/models/miur
git commit -m "feat(miur): modelli ImportDiffScuola/ImportDiffRiga agganciati a ImportRun"
```

---

### Task 3: PORO `Miur::ImportDiff` — calcolo pre-swap in TEMP tables

Il cuore. Due fasi separate perché il run viene creato DOPO lo swap: `calcola`
(pre-swap: legge staging + partizione vecchia, scrive TEMP tables) e
`persisti(run)` (post-swap: travasa dalle TEMP alle tabelle vere). Le TEMP
sopravvivono allo swap perché vivono sulla connessione, non sulle tabelle.

**Files:**
- Create: `app/models/miur/import_diff.rb`
- Test: `test/models/miur/import_diff_test.rb` (create)

**Step 1: Scrivi il test fallente**

Il test simula il contesto del rake: dati "vecchi" nella partizione vera
(via `Miur::Adozione.create!`, come `miur_cambia_religione_test.rb`) e dati
"nuovi" in una staging creata a mano.

```ruby
require "test_helper"

class Miur::ImportDiffTest < ActiveSupport::TestCase
  ANNO = "202627".freeze
  STG  = "miur_adozioni_stg_test".freeze

  setup do
    @conn = ActiveRecord::Base.connection
    @conn.execute("DROP TABLE IF EXISTS #{STG}")
    @conn.execute("CREATE TABLE #{STG} (LIKE miur_adozioni INCLUDING DEFAULTS)")
    Miur::Scuola.create!(anno_scolastico: ANNO, codice_scuola: "MOEE000001",
                         provincia: "MODENA", tipo_scuola: "SCUOLA PRIMARIA")
  end

  teardown do
    @conn.execute("DROP TABLE IF EXISTS #{STG}")
  end

  test "classifica esistente/nuova/sparita e persiste rollup + dettaglio" do
    # vecchia partizione: scuola A con 2 righe, scuola C (sparirà)
    crea_vecchia("MOEE000001", "9781111111111")
    crea_vecchia("MOEE000001", "9782222222222")
    crea_vecchia("MOEE000003", "9783333333333")
    # staging: scuola A perde la 222 e guadagna la 444; scuola B è nuova
    crea_staging("MOEE000001", "9781111111111")
    crea_staging("MOEE000001", "9784444444444")
    crea_staging("MOEE000002", "9785555555555")

    diff = Miur::ImportDiff.new(anno: ANNO, staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: ANNO)
    diff.persisti(run)

    per_categoria = run.diff_scuole.group_by(&:categoria)
    assert_equal %w[MOEE000001], per_categoria["esistente"].map(&:codicescuola)
    assert_equal %w[MOEE000002], per_categoria["nuova"].map(&:codicescuola)
    assert_equal %w[MOEE000003], per_categoria["sparita"].map(&:codicescuola)

    esistente = per_categoria["esistente"].first
    assert_equal 1, esistente.righe_aggiunte   # la 444
    assert_equal 1, esistente.righe_rimosse    # la 222
    assert_equal "MODENA", esistente.provincia # da miur_scuole

    # dettaglio SOLO per la scuola esistente
    assert_equal %w[MOEE000001], run.diff_righe.distinct.pluck(:codicescuola)
    assert_equal ["9784444444444"], run.diff_righe.aggiunte.pluck(:codiceisbn)
    assert_equal ["9782222222222"], run.diff_righe.rimosse.pluck(:codiceisbn)
  end

  test "senza partizione vecchia (primo import anno) il diff si salta" do
    # anno senza partizione: to_regclass torna NULL
    diff = Miur::ImportDiff.new(anno: "209900", staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "209900")
    diff.persisti(run)
    assert_not run.diff?
  end

  test "senza differenze non persiste nulla" do
    crea_vecchia("MOEE000001", "9781111111111")
    crea_staging("MOEE000001", "9781111111111")

    diff = Miur::ImportDiff.new(anno: ANNO, staging: STG)
    diff.calcola
    run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: ANNO)
    diff.persisti(run)
    assert_not run.diff?
  end

  private

  def crea_vecchia(codicescuola, isbn)
    Miur::Adozione.create!(anno_scolastico: ANNO, codicescuola: codicescuola,
                           codiceisbn: isbn, annocorso: "1", sezioneanno: "A",
                           combinazione: "X", disciplina: "ITALIANO",
                           tipogradoscuola: "EE", titolo: "TITOLO #{isbn}")
  end

  def crea_staging(codicescuola, isbn)
    @conn.execute(<<~SQL)
      INSERT INTO #{STG} (anno_scolastico, codicescuola, codiceisbn, annocorso,
                          sezioneanno, combinazione, disciplina, tipogradoscuola, titolo)
      VALUES ('#{ANNO}', '#{codicescuola}', '#{isbn}', '1', 'A', 'X',
              'ITALIANO', 'EE', 'TITOLO #{isbn}')
    SQL
  end
end
```

ATTENZIONE (memoria progetto): i test girano in transazione — qui non serve
`after_commit`, tutto è sincrono, nessun problema. Ma le TEMP tables vivono
sulla connessione dei test: usare la STESSA connessione (`ActiveRecord::Base.connection`)
sia nel PORO che nel test.

**Step 2: Verifica che fallisca**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_diff_test.rb
```

Atteso: FAIL (`uninitialized constant Miur::ImportDiff`).

**Step 3: Implementa `app/models/miur/import_diff.rb`**

```ruby
# Diff MIUR-vs-MIUR di un import adozioni (design 2026-07-08-miur-import-diff-design.md).
#
# Due fasi, perché il run ImportRun nasce DOPO lo swap di partizione:
#   calcola   — PRE-swap: partizione vecchia e staging convivono nel DB; il diff
#               (EXCEPT sulla class-key) finisce in TEMP tables sulla connessione.
#   persisti  — POST-swap: travasa le TEMP nelle tabelle vere, legate al run.
#
# La classificazione esistente/nuova/sparita è puro confronto MIUR (presenza del
# codicescuola nelle due partizioni), MAI stato dell'account. Il dettaglio riga
# si salva solo per le scuole "esistente" (le rettifiche azionabili).
#
# ATTENZIONE: stessa connessione per calcola e persisti (le TEMP sono per-connessione).
class Miur::ImportDiff
  CLASS_KEY = %w[codicescuola annocorso sezioneanno combinazione codiceisbn disciplina].freeze
  # Oltre questo numero di righe di dettaglio (import anomalo, non una rettifica)
  # si salvano solo i rollup: mai cap silenzioso, il salto viene loggato.
  MAX_DETTAGLIO = 200_000
  TMP_RIGHE  = "miur_diff_righe_tmp".freeze
  TMP_SCUOLE = "miur_diff_scuole_tmp".freeze

  def initialize(anno:, staging: "miur_adozioni_stg")
    @anno = anno.to_s
    @staging = staging
    @calcolato = false
  end

  attr_reader :anno, :staging

  # Primo import dell'anno: nessuna partizione vecchia => nessun diff possibile.
  def partizione
    @partizione ||= "miur_adozioni_#{anno}"
  end

  def partizione_esiste?
    conn.select_value("SELECT to_regclass('#{partizione}')").present?
  end

  def calcola
    return unless partizione_esiste?

    key = CLASS_KEY.join(", ")
    conn.execute("DROP TABLE IF EXISTS #{TMP_RIGHE}")
    conn.execute("DROP TABLE IF EXISTS #{TMP_SCUOLE}")

    # Dettaglio: EXCEPT sulla sola class-key (un cambio di titolo a parità di
    # ISBN non è una rettifica). titolo/tipogradoscuola arricchiti dopo, dal
    # lato giusto: '+' dalla staging, '-' dalla partizione vecchia (che con lo
    # swap sparisce: questa è l'unica copia superstite).
    conn.execute(<<~SQL)
      CREATE TEMP TABLE #{TMP_RIGHE} ON COMMIT PRESERVE ROWS AS
      WITH aggiunte AS (
        SELECT #{key} FROM #{staging} WHERE anno_scolastico = '#{anno}'
        EXCEPT
        SELECT #{key} FROM #{partizione}
      ),
      rimosse AS (
        SELECT #{key} FROM #{partizione}
        EXCEPT
        SELECT #{key} FROM #{staging} WHERE anno_scolastico = '#{anno}'
      )
      SELECT '+' AS segno, a.*,
             (SELECT s.titolo FROM #{staging} s
               WHERE s.codicescuola = a.codicescuola AND s.codiceisbn = a.codiceisbn
                 AND s.anno_scolastico = '#{anno}' LIMIT 1) AS titolo,
             (SELECT s.tipogradoscuola FROM #{staging} s
               WHERE s.codicescuola = a.codicescuola AND s.anno_scolastico = '#{anno}'
               LIMIT 1) AS tipogradoscuola
      FROM aggiunte a
      UNION ALL
      SELECT '-' AS segno, r.*,
             (SELECT p.titolo FROM #{partizione} p
               WHERE p.codicescuola = r.codicescuola AND p.codiceisbn = r.codiceisbn
               LIMIT 1) AS titolo,
             (SELECT p.tipogradoscuola FROM #{partizione} p
               WHERE p.codicescuola = r.codicescuola LIMIT 1) AS tipogradoscuola
      FROM rimosse r
    SQL

    # Rollup per scuola: categoria dal FULL OUTER JOIN dei codici presenti nelle
    # due partizioni; le "esistente" entrano solo se hanno righe nel diff.
    # provincia da miur_scuole dell'anno (NULL se il codice non è in anagrafe).
    conn.execute(<<~SQL)
      CREATE TEMP TABLE #{TMP_SCUOLE} ON COMMIT PRESERVE ROWS AS
      WITH vecchi AS (SELECT DISTINCT codicescuola FROM #{partizione}),
      nuovi AS (SELECT DISTINCT codicescuola FROM #{staging} WHERE anno_scolastico = '#{anno}'),
      classificate AS (
        SELECT COALESCE(v.codicescuola, n.codicescuola) AS codicescuola,
               CASE WHEN v.codicescuola IS NULL THEN 'nuova'
                    WHEN n.codicescuola IS NULL THEN 'sparita'
                    ELSE 'esistente' END AS categoria
        FROM vecchi v FULL OUTER JOIN nuovi n USING (codicescuola)
      ),
      conteggi AS (
        SELECT codicescuola,
               COUNT(*) FILTER (WHERE segno = '+') AS righe_aggiunte,
               COUNT(*) FILTER (WHERE segno = '-') AS righe_rimosse,
               MAX(tipogradoscuola) AS tipogradoscuola
        FROM #{TMP_RIGHE} GROUP BY codicescuola
      )
      SELECT c.codicescuola, c.categoria,
             ms.provincia,
             COALESCE(cnt.tipogradoscuola,
                      (SELECT MAX(x.tipogradoscuola) FROM #{staging} x
                        WHERE x.codicescuola = c.codicescuola
                          AND x.anno_scolastico = '#{anno}')) AS tipogradoscuola,
             COALESCE(cnt.righe_aggiunte, 0) AS righe_aggiunte,
             COALESCE(cnt.righe_rimosse, 0) AS righe_rimosse
      FROM classificate c
      LEFT JOIN conteggi cnt USING (codicescuola)
      LEFT JOIN miur_scuole ms
        ON ms.codice_scuola = c.codicescuola AND ms.anno_scolastico = '#{anno}'
      WHERE c.categoria <> 'esistente' OR cnt.codicescuola IS NOT NULL
    SQL

    @calcolato = true
  end

  def persisti(run)
    return unless @calcolato

    conn.execute(<<~SQL)
      INSERT INTO miur_import_diff_scuole
        (import_run_id, codicescuola, categoria, provincia, tipogradoscuola,
         righe_aggiunte, righe_rimosse, created_at)
      SELECT #{run.id}, codicescuola, categoria, provincia, tipogradoscuola,
             righe_aggiunte, righe_rimosse, now()
      FROM #{TMP_SCUOLE}
    SQL

    dettaglio = conn.select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM #{TMP_RIGHE} r
      JOIN #{TMP_SCUOLE} s ON s.codicescuola = r.codicescuola AND s.categoria = 'esistente'
    SQL
    if dettaglio > MAX_DETTAGLIO
      Rails.logger.warn("[Miur::ImportDiff] run #{run.id}: dettaglio saltato " \
                        "(#{dettaglio} righe > #{MAX_DETTAGLIO}); salvati solo i rollup")
    else
      conn.execute(<<~SQL)
        INSERT INTO miur_import_diff_righe
          (import_run_id, codicescuola, segno, codiceisbn, titolo, disciplina,
           annocorso, sezioneanno, combinazione, created_at)
        SELECT #{run.id}, r.codicescuola, r.segno, r.codiceisbn, r.titolo,
               r.disciplina, r.annocorso, r.sezioneanno, r.combinazione, now()
        FROM #{TMP_RIGHE} r
        JOIN #{TMP_SCUOLE} s ON s.codicescuola = r.codicescuola AND s.categoria = 'esistente'
      SQL
    end
  ensure
    conn.execute("DROP TABLE IF EXISTS #{TMP_RIGHE}")
    conn.execute("DROP TABLE IF EXISTS #{TMP_SCUOLE}")
  end

  private

  def conn = ActiveRecord::Base.connection
end
```

NOTA per l'esecutore: `anno` e `staging` arrivano SOLO dal task rake (mai da
input utente) — l'interpolazione SQL è nello stile del resto di `miur.rake`.
Se il test sulla scuola "sparita" fallisce su `tipogradoscuola` NULL va bene
così (la scuola non è più in staging): il campo è informativo, non filtrante.

**Step 4: Verifica che passi**

```bash
docker exec prova-app-1 bin/rails test test/models/miur/import_diff_test.rb
```

Atteso: 3 runs, 0 failures. Se fallisce il primo test sul dettaglio, controlla
che la partizione `miur_adozioni_202627` esista nel DB di test (il test di
`cambia_religione` la usa già, quindi c'è).

**Step 5: Commit**

```bash
git add app/models/miur/import_diff.rb test/models/miur/import_diff_test.rb
git commit -m "feat(miur): Miur::ImportDiff calcola il diff pre-swap in TEMP tables"
```

---

### Task 4: Integrazione nel task rake `miur:importa_adozioni`

**Files:**
- Modify: `lib/tasks/miur.rake` (~righe 182-210)

**Step 1: Aggiungi calcolo pre-swap e persistenza post-run**

In `lib/tasks/miur.rake`, DOPO il blocco indici+ANALYZE (riga ~182,
`puts "Indici + PK + CHECK + ANALYZE su staging completati"`) e PRIMA di
`part = "miur_adozioni_#{anno}"`, inserisci:

```ruby
      # Diff MIUR-vs-MIUR pre-swap (design 2026-07-08-miur-import-diff-design.md):
      # partizione vecchia e staging convivono solo qui. Non-fatale: il diff è
      # osservabilità, lo swap è il lavoro critico.
      diff = Miur::ImportDiff.new(anno: anno, staging: MIUR_ADOZIONI_STG)
      begin
        diff.calcola
      rescue => e
        diff = nil
        Rails.logger.error("[Miur::ImportDiff] calcolo fallito (import prosegue): #{e.class}: #{e.message}")
      end
```

Poi, DOPO `Miur::ImportRun.create!(...)` (riga ~206) — assegna la create! a
una variabile e persisti:

```ruby
      run = Miur::ImportRun.create!(
        dataset: "adozioni", anno_scolastico: anno,
        righe_totali: totale, delta_righe: prev&.righe_totali ? totale - prev.righe_totali : nil,
        completed_at: Time.current
      )

      begin
        diff&.persisti(run)
        puts "Diff import: #{run.diff_scuole.count} scuole toccate" if diff
      rescue => e
        Rails.logger.error("[Miur::ImportDiff] persistenza fallita (import ok): #{e.class}: #{e.message}")
      end
```

(La `create!` esiste già: la modifica è solo `run = ` davanti + il blocco diff dopo.)

**Step 2: Verifica sintassi e che i test esistenti non si rompano**

```bash
docker exec prova-app-1 bin/rails runner 'Rails.application.load_tasks; puts "ok"'
docker exec prova-app-1 bin/rails test test/tasks/
```

Atteso: `ok`; suite tasks verde.

**Step 3: Commit**

```bash
git add lib/tasks/miur.rake
git commit -m "feat(miur): importa_adozioni calcola e persiste il diff (non-fatale)"
```

---

### Task 5: Routes + controller `Miur::ImportRunsController` (admin-only)

**Files:**
- Modify: `config/routes.rb` (dentro `scope '/:account_id'`, vicino a controllo_adozioni ~riga 376)
- Create: `app/controllers/miur/import_runs_controller.rb`
- Create: `app/controllers/miur/reconciles_controller.rb` (bottone Blocco 3)
- Test: `test/controllers/miur/import_runs_controller_test.rb` (create)

**Step 1: Scrivi il test fallente**

Guarda un controller test esistente in `test/controllers/` per il pattern di
login/account del progetto (helper di autenticazione + fixture account) e usa
lo stesso. Struttura attesa:

```ruby
require "test_helper"

class Miur::ImportRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # usa l'helper di login del progetto (vedi altri controller test) con un utente ADMIN
    @run = Miur::ImportRun.create!(dataset: "adozioni", anno_scolastico: "202627",
                                   righe_totali: 100, completed_at: Time.current)
    @run.diff_scuole.create!(codicescuola: "MOEE000001", categoria: "esistente",
                             provincia: "MODENA", tipogradoscuola: "SCUOLA PRIMARIA",
                             righe_aggiunte: 2, righe_rimosse: 1)
    @run.diff_righe.create!(codicescuola: "MOEE000001", segno: "+",
                            codiceisbn: "9781111111111", titolo: "NUOVO LIBRO",
                            disciplina: "ITALIANO", annocorso: "1", sezioneanno: "A")
  end

  test "index elenca gli import" do
    get miur_import_runs_path(account_id: <account fixture id>)
    assert_response :success
    assert_select "body", /202627/
  end

  test "show mostra il breakdown del diff" do
    get miur_import_run_path(@run, account_id: <account fixture id>)
    assert_response :success
    assert_select "body", /MODENA/
  end

  test "member non admin viene respinto" do
    # login come member non-admin
    get miur_import_runs_path(account_id: <account fixture id>)
    assert_redirected_to <root del progetto>
  end
end
```

(L'esecutore DEVE sostituire i segnaposto col pattern reale dei controller
test del progetto — es. `test/controllers/controllo_adozioni_controller_test.rb`
se esiste, altrimenti un altro test admin-gated.)

**Step 2: Verifica che fallisca** (route inesistente)

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/import_runs_controller_test.rb
```

**Step 3: Routes** — in `config/routes.rb`, dentro `scope '/:account_id'`,
dopo il blocco `controllo_adozioni` (~riga 391):

```ruby
    namespace :miur do
      resources :import_runs, only: %i[index show] do
        resource :reconcile, only: :create, module: :import_runs
      end
    end
```

**Step 4: Controller** `app/controllers/miur/import_runs_controller.rb`:

```ruby
# Storia degli import MIUR con drill-down del diff (pagina standalone, design
# 2026-07-08-miur-import-diff-design.md). Dati MIUR-globali (nessuno scope
# account sui dati), ma la pagina vive nel contesto account: solo admin.
class Miur::ImportRunsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    @runs = Miur::ImportRun.adozioni.order(completed_at: :desc).limit(50)
  end

  def show
    @run = Miur::ImportRun.adozioni.find(params[:id])
    @provincia = params[:provincia].presence

    scuole = @run.diff_scuole.per_provincia(@provincia)
    @riepilogo_province = @run.diff_scuole
      .group(:provincia, :categoria)
      .pluck(:provincia, :categoria, Arel.sql("COUNT(*)"),
             Arel.sql("SUM(righe_aggiunte)"), Arel.sql("SUM(righe_rimosse)"))
    @esistenti = scuole.esistenti.order(Arel.sql("righe_aggiunte + righe_rimosse DESC"))
    @nuove_count = scuole.nuove.count
    @sparite = scuole.sparite.order(:provincia, :codicescuola)

    # Dettaglio righe della scuola selezionata (drill)
    if params[:codicescuola].present?
      @scuola_focus = params[:codicescuola]
      @righe = @run.diff_righe.where(codicescuola: @scuola_focus)
                   .order(:annocorso, :sezioneanno, :disciplina, :segno)
      @sostituzioni = sostituzioni(@righe)
    end
  end

  private

  def require_admin
    redirect_to root_path, alert: "Solo per amministratori" unless Current.admin?
  end

  # "Sostituzione da verificare": stessa classe+disciplina con sia '+' che '-'
  # (il MIUR ha cambiato libro). Derivata a lettura, non persistita.
  def sostituzioni(righe)
    righe.group_by { |r| [r.annocorso, r.sezioneanno, r.combinazione, r.disciplina] }
         .select { |_, rr| rr.map(&:segno).uniq.sort == ["+", "-"] }
  end
end
```

`app/controllers/miur/import_runs/reconciles_controller.rb`:

```ruby
# Bottone "Ri-reconcilia questa provincia": convenienza manuale (MAI automatico).
# Accoda il reconcile per l'account corrente; le protezioni sul lavoro utente
# sono nel Reconciler stesso (ON CONFLICT DO NOTHING + orfane protette).
class Miur::ImportRuns::ReconcilesController < ApplicationController
  before_action :authenticate_user!

  def create
    run = Miur::ImportRun.adozioni.find(params[:import_run_id])
    provincia = params.require(:provincia)
    head :forbidden and return unless Current.admin?

    ReconcileAdozioniJob.perform_later(Current.account, provincia: provincia,
                                       anno: run.anno_scolastico)
    redirect_to miur_import_run_path(run, provincia: provincia),
                notice: "Reconcile accodato per #{provincia}"
  end
end
```

NOTA route: con `module: :import_runs` il controller del reconcile va in
`app/controllers/miur/import_runs/reconciles_controller.rb` (namespace
`Miur::ImportRuns::`). Verifica con `bin/rails routes -g import_runs`.

**Step 5: Viste minime** (Task 6 le rifinisce — qui bastano a far passare i test):

`app/views/miur/import_runs/index.html.erb` e `show.html.erb` — segui i
pattern delle viste `controllo_adozioni` (classi CSS `ca-*`, stile Fizzy,
NO Tailwind). Per l'index: lista dei run con data, `righe_totali`,
`delta_righe`, conteggi diff (`run.diff_scuole.esistenti.count` ecc. —
attenzione N+1: precaricare con un `GROUP BY import_run_id, categoria` in
controller se la lista è lunga). Per la show: tabella riepilogo province,
lista `@esistenti` con link drill (`?codicescuola=...`), sezione `@righe`
con segno +/− e blocco `@sostituzioni` evidenziato, bottone reconcile:

```erb
<%= button_to "Ri-reconcilia #{@provincia}",
      miur_import_run_reconcile_path(@run, provincia: @provincia),
      method: :post, class: "btn" if @provincia %>
```

**Step 6: Verifica che i test passino**

```bash
docker exec prova-app-1 bin/rails test test/controllers/miur/
```

**Step 7: Commit**

```bash
git add config/routes.rb app/controllers/miur app/views/miur test/controllers/miur
git commit -m "feat(miur): pagina import_runs con drill-down diff e reconcile manuale"
```

---

### Task 6: Link dalla freshness + rifinitura viste

**Files:**
- Modify: `app/views/controllo_adozioni/_freshness.html.erb`
- Modify: `app/views/miur/import_runs/index.html.erb`, `show.html.erb`

**Step 1: Freshness → link alla show dell'ultimo run**

In `_freshness.html.erb`, avvolgi la data in un link (solo per admin, la
pagina è admin-only):

```erb
Dati MIUR aggiornati al
<% data = "#{run.completed_at.day} #{I18n.t("date.abbr_month_names")[run.completed_at.month]}" %>
<% if Current.admin? %>
  <%= link_to miur_import_run_path(run) do %><strong><%= data %></strong><% end %>
<% else %>
  <strong><%= data %></strong>
<% end %>
```

**Step 2: Rifinisci le viste** seguendo Fizzy/`ca-*` (usa la skill
frontend-design se serve; riferimento pattern: `app/views/controllo_adozioni/`).
Requisiti dal design:

- index: più recente in cima, sintesi per run (righe +/−, 3 conteggi scuole, delta)
- show: breakdown provincia×grado; drill scuola → righe con titolo/disciplina;
  nuove → conteggio con `link_to controllo_adozioni_index_path` (step promuovibili);
  sparite → elenco; sostituzioni evidenziate "da verificare"

**Step 3: Verifica visiva in dev**

```bash
# dev: naviga /:account_id/miur/import_runs con un run + diff seminati a mano se serve
docker exec prova-app-1 bin/rails runner '
  run = Miur::ImportRun.adozioni.order(:completed_at).last
  puts "run #{run&.id} diff_scuole=#{run&.diff_scuole&.count}"'
```

Se il diff è vuoto in dev (nessun import recente col nuovo codice), semina un
run finto con 2-3 diff_scuole/righe da console per il check visivo.

**Step 4: Commit**

```bash
git add app/views
git commit -m "feat(miur): freshness linka il dettaglio import; viste diff rifinite"
```

---

### Task 7: Sintesi diff nella mail dello scraper

**Files:**
- Modify: `app/mailers/scraping_mailer.rb`
- Modify: `app/views/scraping_mailer/scraping_completed.html.erb`

**Step 1: Nel mailer**, carica l'ultimo run (la firma del job NON cambia —
Sidekiq passa primitivi):

```ruby
    @ultimo_run = Miur::ImportRun.adozioni.order(:completed_at).last
```

**Step 2: Nella view della mail**, sotto il blocco esistente:

```erb
<% if @ultimo_run&.diff? %>
  <% s = @ultimo_run.diff_scuole %>
  <h3>Rettifiche di questo import</h3>
  <p>
    +<%= s.sum(:righe_aggiunte) %> / -<%= s.sum(:righe_rimosse) %> righe
    su <%= s.esistenti.count %> scuole esistenti ·
    <%= s.nuove.count %> nuove da promuovere ·
    <%= s.sparite.count %> sparite.<br>
    Province più toccate:
    <%= s.esistenti.group(:provincia).order(Arel.sql("SUM(righe_aggiunte + righe_rimosse) DESC"))
         .limit(3).sum(Arel.sql("righe_aggiunte + righe_rimosse")).keys.compact.join(", ") %>
  </p>
<% end %>
```

NOTA: la mail non ha contesto account → nessun `link_to` con account_id
(indicare il percorso come testo, es. "vedi /miur/import_runs nell'app").

**Step 3: Verifica** — test mailer esistente o anteprima:

```bash
docker exec prova-app-1 bin/rails test test/mailers/ 2>/dev/null || true
# anteprima manuale in dev via letter_opener se configurata
```

**Step 4: Commit**

```bash
git add app/mailers app/views/scraping_mailer
git commit -m "feat(miur): sintesi diff import nella mail dello scraper"
```

---

### Task 8: Suite completa + verifica end-to-end

**Step 1: Tutta la suite**

```bash
docker exec prova-app-1 bin/rails test
```

Atteso: verde (la suite era verde al commit a3eeeebe).

**Step 2: Verifica end-to-end in dev** (REQUIRED SUB-SKILL: superpowers:verification-before-completion)

Simula un import con diff: in dev la partizione 202627 è popolata; crea una
staging con una piccola modifica e lancia il task... — troppo invasivo in dev
(swap reale). Alternativa sicura: verifica il PORO da console contro una
staging giocattolo (come nel test), e la pagina con run seminato. Il primo
collaudo reale del task completo avverrà col prossimo giro di rettifiche MIUR
in prod: dopo il deploy, controllare che `Miur::ImportRun...last.diff?` sia
true e la pagina renda.

**Step 3: STOP — riepilogo per l'utente, NIENTE commit/push automatico oltre
i commit di task già fatti.** Mostrare `git log --oneline` dei commit creati e
chiedere se pushare.

---

## Fuori scope (ribadito dal design — NON implementare)

- Re-reconcile automatico post-import
- Dettaglio riga per il primo import dell'anno (si salta: nessuna partizione vecchia)
- Risoluzione automatica delle sostituzioni su righe protette
- Qualsiasi filtro per account nel motore di diff
