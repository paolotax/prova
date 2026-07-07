# MIUR Fase 2 — Logica: Classificazione unica Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (o superpowers:subagent-driven-development) per implementare questo piano task per task.

**Goal:** Eliminare la triplice riscrittura delle regole di stato del passaggio anno (promuovibile, promossa, nel_miur, anomalie, e la classificazione cambi-codice match/suggerimento/nuova) consolidandole in un'unica sorgente di verità riusata da `Dashboard`, `PassaggioAnno` e `Panoramica`.

**Architecture:** Non un unico oggetto Ruby per scuola (non scalerebbe sull'editore, 24k scuole → gli aggregati DEVONO restare SQL), ma **un unico modulo di predicati SQL canonici** (`ControlloAdozioni::Classificazione`) che i tre PORO includono invece di ridefinire. La classificazione cambi-codice (oggi scritta 2 volte: `PassaggioAnno::SQL_CLASSIFICA` in SQL e `Panoramica#build_cambi_codice` in Ruby) diventa un'unica implementazione SQL consumata da entrambi. Ogni consolidamento è protetto da un **test di equivalenza** (vecchio conteggio == nuovo) prima del taglio.

**Tech Stack:** Rails 8.1, PostgreSQL (predicati SQL parametrizzati via `sanitize_sql`), Minitest + fixtures, PORO in `app/models/controllo_adozioni/`.

**Fuori scope (track separati, non questa fase):**
- Riscrittura delle ~60 Stat utente (`stats.testo`: 49 usano `new_adozioni`, 41 `new_scuole`, 32 `import_adozioni`) e drop delle 3 viste ponte → track "Stat cleanup".
- `import_scuole` → `miur_anagrafe_scuole` → Fase 4.
- Rimozione completa di `import_adozioni` + repoint `AdozioneComunicata#belongs_to :import_adozione` → track separato (tocca la riconciliazione comunicate, rischio a sé).

---

## Contesto: inventario della duplicazione (verificato 2026-07-07)

**Regola `promuovibile`** (scuola in anagrafe + presente nel MIUR anno corrente EE + senza classi attive dell'anno) — scritta in:
- `app/models/controllo_adozioni/dashboard.rb:101-108` (SQL, frammento `promuovibile`)
- `app/models/controllo_adozioni/passaggio_anno.rb:67-81` (`promuovibili_count`, Arel `.where.exists`)
- `app/models/controllo_adozioni/panoramica.rb:150-162` (`promuovibili_codici`, Ruby set-based)

**Regola `promossa`** (ha classi attive con `anno_scolastico >= anno`):
- `dashboard.rb:97-100` (SQL `promossa`)
- `panoramica.rb:107-110` (`promossa?`, Ruby su `max_anno_attive`)

**Regola `nel_miur` / `con_anomalie`:** `dashboard.rb:119-123` (SQL) vs `panoramica.rb` (`new_counts.key?`, `anomalie_by_codice`).

**Classificazione cambi-codice `match|suggerimento|nuova`** — DUE implementazioni tenute allineate a mano:
- `app/models/controllo_adozioni/passaggio_anno.rb:116-168` (`SQL_CLASSIFICA`, SQL con CTE `orfane`/`nuovi`)
- `app/models/controllo_adozioni/panoramica.rb:242-296` (`build_cambi_codice`, Ruby: `orfane_per_comune`, `denom_simili?`)
- Allineate dal test `test/models/controllo_adozioni/passaggio_anno_test.rb` (anti-deriva).

**Anni hardcoded** (contesto per Task 1): `app/jobs/reconcile_account_job.rb:4` (`ANNI = %w[202526 202627]`), `app/jobs/import_scuole_per_zona_job.rb:8` (`ANNO_SCOLASTICO = "202526"`), `app/controllers/controllo_adozioni/promozioni_controller.rb:58` (fallback `"202627"`). (Gli hardcoded `202526` in `adozioni_comunicate`, `titoli`, `classe`, `scuole/stats`, `cache.rake`, `agenda` sono la "campagna comunicate corrente", track separato — NON toccarli qui.)

**Strategia di test (per ogni task di consolidamento):** prima si scrive un test che calcola il valore con la vecchia via e con la nuova e ne **asserisce l'uguaglianza** su un dataset fixture non banale (2 province, scuole promuovibili/promosse/mancanti/con anomalie); poi si sostituisce la vecchia implementazione con la nuova; il test resta come guardia anti-regressione.

---

## Task 1: `AnnoScolastico` value object

**Files:**
- Create: `app/models/anno_scolastico.rb`
- Create: `test/models/anno_scolastico_test.rb`
- Modify: `app/jobs/reconcile_account_job.rb:4-8`
- Modify: `app/controllers/controllo_adozioni/promozioni_controller.rb:58`

**Step 1: Write the failing test**

```ruby
# test/models/anno_scolastico_test.rb
require "test_helper"

class AnnoScolasticoTest < ActiveSupport::TestCase
  test "corrente delega a Miur.anno_corrente" do
    Miur::Scuola.stub :maximum, "202627" do
      assert_equal "202627", AnnoScolastico.corrente.to_s
    end
  end

  test "successivo e precedente scorrono di un anno" do
    a = AnnoScolastico.new("202526")
    assert_equal "202627", a.successivo.to_s
    assert_equal "202425", a.precedente.to_s
  end

  test "label umana" do
    assert_equal "2025/26", AnnoScolastico.new("202526").label
  end

  test "comparabile e uguale per valore" do
    assert AnnoScolastico.new("202627") > AnnoScolastico.new("202526")
    assert_equal AnnoScolastico.new("202526"), AnnoScolastico.new("202526")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/anno_scolastico_test.rb`
Expected: FAIL con "uninitialized constant AnnoScolastico"

**Step 3: Write minimal implementation**

```ruby
# app/models/anno_scolastico.rb
# Value object per l'anno scolastico MIUR nel formato "AAAABB" (es. "202526").
# Centralizza Miur.anno_corrente, lo scorrimento e la label umana, togliendo
# gli anni hardcoded sparsi nei job/controller.
class AnnoScolastico
  include Comparable

  def self.corrente
    v = Miur.anno_corrente
    v && new(v)
  end

  def initialize(valore)
    @valore = valore.to_s
  end

  attr_reader :valore
  alias to_s valore

  def successivo = self.class.new(scorri(+1))
  def precedente = self.class.new(scorri(-1))

  def label = "#{valore[0, 4]}/#{valore[4, 2]}"

  def <=>(other) = valore <=> other.to_s
  def eql?(other) = other.is_a?(self.class) && valore == other.valore
  def hash = valore.hash

  private

  # "202526" -> inizio 2025; scorri(+1) -> "202627".
  def scorri(delta)
    inizio = valore[0, 4].to_i + delta
    format("%<a>d%<b>02d", a: inizio, b: (inizio + 1) % 100)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/anno_scolastico_test.rb`
Expected: PASS (4 runs)

**Step 5: Sostituisci gli anni hardcoded a rischio (solo passaggio anno)**

In `app/jobs/reconcile_account_job.rb`: sostituisci `ANNI = %w[202526 202627]` con la coppia corrente/precedente derivata:

```ruby
# ReconcileAccountJob: riconcilia l'anno corrente e il precedente (storico).
def anni
  corrente = AnnoScolastico.corrente or return []
  [corrente.precedente.to_s, corrente.to_s]
end
```
e nel `perform` usa `anni.each { |anno| ... }` al posto di `ANNI.each`.

In `promozioni_controller.rb:58` sostituisci il fallback letterale:
```ruby
(AnnoScolastico.corrente&.to_s).presence || Miur::Adozione.maximum(:anno_scolastico)
```

**Step 6: Run the full controllo_adozioni + jobs suite**

Run: `docker exec prova-app-1 bin/rails test test/models/anno_scolastico_test.rb test/jobs/reconcile_account_job_test.rb test/controllers/controllo_adozioni`
Expected: PASS (o crea `reconcile_account_job_test.rb` se assente e testa che accoda 2 anni).

**Step 7: Commit**

```bash
git add app/models/anno_scolastico.rb test/models/anno_scolastico_test.rb \
        app/jobs/reconcile_account_job.rb app/controllers/controllo_adozioni/promozioni_controller.rb
git commit -m "feat(controllo-adozioni): AnnoScolastico value object per gli anni del passaggio"
```

---

## Task 2: `ControlloAdozioni::Classificazione` — predicati SQL canonici

**Files:**
- Create: `app/models/controllo_adozioni/classificazione.rb`
- Create: `test/models/controllo_adozioni/classificazione_test.rb`
- Modify: `app/models/controllo_adozioni/dashboard.rb:96-137` (usa i predicati)
- Modify: `app/models/controllo_adozioni/passaggio_anno.rb:67-89` (usa i predicati)

**Contesto:** i predicati devono essere frammenti SQL parametrici su `:anno`, riferiti a un alias scuola configurabile (`sc`), così Dashboard (subquery su `scuole sc`) e PassaggioAnno (Arel su `scuole`) li condividono. Panoramica resta per-scuola (Task lasciato invariato qui: consuma già gli stessi conteggi; l'allineamento è garantito dal test di equivalenza).

**Step 1: Write the failing test (equivalenza)**

```ruby
# test/models/controllo_adozioni/classificazione_test.rb
require "test_helper"

class ControlloAdozioni::ClassificazioneTest < ActiveSupport::TestCase
  test "i predicati SQL producono gli stessi conteggi di Dashboard" do
    # dataset: usa le fixture + uno snapshot MIUR minimo (vedi helper sotto)
    account = accounts(:fizzy)
    anno = "202627"
    # Conteggio via predicato canonico
    promuovibili = ControlloAdozioni::Classificazione.new(anno: anno)
      .conta(account.scuole, :promuovibile)
    # Conteggio via Dashboard (vecchia via)
    da_dashboard = ControlloAdozioni::Dashboard.new(account: account).totali[:da_promuovere]
    assert_equal da_dashboard, promuovibili
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/classificazione_test.rb`
Expected: FAIL con "uninitialized constant ControlloAdozioni::Classificazione"

**Step 3: Write minimal implementation (predicati + conta)**

```ruby
# app/models/controllo_adozioni/classificazione.rb
module ControlloAdozioni
  # Sorgente unica delle regole di stato di una scuola rispetto allo snapshot MIUR.
  # Espone frammenti SQL parametrici su :anno (alias scuola = "sc") riusati da
  # Dashboard (aggregato/provincia) e PassaggioAnno (aggregato/step). Panoramica
  # applica le stesse regole per scuola; il test di equivalenza le tiene allineate.
  class Classificazione
    def initialize(anno:)
      @anno = anno.to_s
    end

    attr_reader :anno

    # Ha classi attive all'anno dello snapshot (>= anno) -> gia' promossa.
    def promossa(sc = "sc")
      return "FALSE" if anno.blank?
      "EXISTS (SELECT 1 FROM classi c WHERE c.scuola_id = #{sc}.id " \
        "AND c.stato = 'attiva' AND c.anno_scolastico >= :anno)"
    end

    # In anagrafe MIUR + adozioni EE nell'anno, ma senza classi attive dell'anno.
    def promuovibile(sc = "sc")
      return "FALSE" if anno.blank?
      <<~SQL.strip
        EXISTS (SELECT 1 FROM miur_scuole ns WHERE ns.codice_scuola = #{sc}.codice_ministeriale
                AND ns.anno_scolastico = :anno)
        AND EXISTS (SELECT 1 FROM miur_adozioni nae WHERE nae.codicescuola = #{sc}.codice_ministeriale
                    AND nae.anno_scolastico = :anno AND nae.tipogradoscuola = 'EE')
        AND NOT (#{promossa(sc)})
      SQL
    end

    def nel_miur(sc = "sc")
      "EXISTS (SELECT 1 FROM miur_adozioni na WHERE na.codicescuola = #{sc}.codice_ministeriale " \
        "AND na.anno_scolastico = :anno)"
    end

    def con_anomalie(sc = "sc")
      "EXISTS (SELECT 1 FROM controllo_anomalie ca WHERE ca.codicescuola = #{sc}.codice_ministeriale)"
    end

    # Conta le scuole dello scope che soddisfano il predicato (per i test di equivalenza).
    def conta(scope, predicato)
      sql = send(predicato, "scuole")
      scope.where(ActiveRecord::Base.sanitize_sql([sql, anno: anno])).count
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/classificazione_test.rb`
Expected: PASS

**Step 5: Rifattorizza Dashboard per usare i predicati**

In `dashboard.rb#sql_righe`, sostituisci i letterali `promossa`/`promuovibile` con
`cl = Classificazione.new(anno: anno)` e interpolando `cl.promossa`, `cl.promuovibile`,
`cl.nel_miur`, `cl.con_anomalie`. NON cambiare la forma della query esterna.

**Step 6: Rifattorizza PassaggioAnno#promuovibili_count / anomalie_count**

Sostituisci l'Arel di `promuovibili_count` (righe 67-81) con `Classificazione.new(anno:).conta(scuole_scope, :promuovibile)` e `anomalie_count` con `.conta(scuole_scope, :con_anomalie)`.

**Step 7: Run the tests**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS — i conteggi sono identici (predicati equivalenti), i test esistenti restano verdi.

**Step 8: Commit**

```bash
git add app/models/controllo_adozioni/classificazione.rb \
        test/models/controllo_adozioni/classificazione_test.rb \
        app/models/controllo_adozioni/dashboard.rb \
        app/models/controllo_adozioni/passaggio_anno.rb
git commit -m "refactor(controllo-adozioni): predicati di stato unici in Classificazione"
```

---

## Task 3: Classificazione cambi-codice unica (match/suggerimento/nuova)

**Files:**
- Modify: `app/models/controllo_adozioni/classificazione.rb` (aggiungi `SQL_CLASSIFICA` + `classifica_per_provincia`)
- Modify: `app/models/controllo_adozioni/passaggio_anno.rb:48-65,116-168` (delega a Classificazione)
- Modify: `app/models/controllo_adozioni/panoramica.rb:242-296` (consuma lo stesso SQL per il tipo)
- Modify: `test/models/controllo_adozioni/passaggio_anno_test.rb` (il test anti-deriva diventa test della sorgente unica)

**Contesto:** oggi `PassaggioAnno::SQL_CLASSIFICA` (SQL) e `Panoramica#build_cambi_codice` (Ruby) classificano gli stessi codici in modo indipendente. Sposta `SQL_CLASSIFICA` (con `NORM`, CTE `orfane`/`nuovi`) dentro `Classificazione`. `PassaggioAnno` chiede a `Classificazione` i conteggi per tipo. `Panoramica#build_cambi_codice` continua a costruire le `Mancante` (gli servono candidati/predecessore per la UI), ma per **il tipo** (match/suggerimento/nuova) usa la stessa regola: estrai il predicato di similarità denominazione in un unico posto (SQL `NORM` ⇄ Ruby `denom_norm` devono coincidere — documenta l'invariante e testalo).

**Step 1: Write the failing test (una sola sorgente)**

```ruby
# test/models/controllo_adozioni/passaggio_anno_test.rb (adatta l'anti-deriva)
test "il conteggio per tipo di PassaggioAnno coincide con la classificazione di Panoramica" do
  # setup: 1 codice nuovo con orfana simile (match), 1 con orfana non simile
  # (suggerimento), 1 senza orfane (nuova) — vedi helper esistente.
  passaggio = ControlloAdozioni::PassaggioAnno.new(account: @account)
  panoramica = ControlloAdozioni::Panoramica.new(account: @account)
  per_tipo = panoramica.cambi_codice.group_by(&:tipo).transform_values(&:size)

  assert_equal per_tipo.fetch(:match, 0),        passaggio.conteggi_codici_nuovi[:match]
  assert_equal per_tipo.fetch(:suggerimento, 0), passaggio.conteggi_codici_nuovi[:suggerimento]
  assert_equal per_tipo.fetch(:nuova, 0),        passaggio.conteggi_codici_nuovi[:nuova]
end
```

**Step 2: Run test to verify it fails or passes as characterization**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/passaggio_anno_test.rb`
Expected: se già allineati, PASS (characterization); serve a bloccare la regressione durante lo spostamento.

**Step 3: Sposta SQL_CLASSIFICA in Classificazione**

Taglia `NORM` e `SQL_CLASSIFICA` da `passaggio_anno.rb` e incollali in `classificazione.rb`. Aggiungi:

```ruby
# In Classificazione: conteggi {match:, suggerimento:, nuova:} per le zone date.
def conteggi_cambi_codice(account:, provincia: nil)
  # ... itera zone_per_grado, esegue SQL_CLASSIFICA, somma per tipo ...
end
```

`PassaggioAnno#conteggi_codici_nuovi` diventa un semplice delega a
`Classificazione.new(anno: anno).conteggi_cambi_codice(account:, provincia:)`.

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/passaggio_anno_test.rb`
Expected: PASS

**Step 5: Documenta e testa l'invariante NORM ⇄ denom_norm**

Aggiungi in `classificazione_test.rb` un test che verifica che la normalizzazione SQL
(`NORM`) e quella Ruby (`Panoramica#denom_norm`, resa pubblica o spostata in
`Classificazione.denom_norm`) diano lo stesso output su un set di stringhe
(`"I.C. Calamandrei"`, `"PIERO  CALAMANDREI"`, accenti, doppi spazi).

**Step 6: Commit**

```bash
git add app/models/controllo_adozioni/classificazione.rb \
        app/models/controllo_adozioni/passaggio_anno.rb \
        app/models/controllo_adozioni/panoramica.rb \
        test/models/controllo_adozioni/passaggio_anno_test.rb \
        test/models/controllo_adozioni/classificazione_test.rb
git commit -m "refactor(controllo-adozioni): classificazione cambi-codice in un'unica sorgente SQL"
```

---

## Task 4: `promuovi_primaria!` delega le adozioni al Reconciler

**Files:**
- Modify: `app/models/scuola.rb:263-...` (`promuovi_primaria!`)
- Modify: `app/jobs/scuola_promuovi_classi_job.rb:7`
- Test: `test/models/scuola_test.rb` (o `test/jobs/scuola_promuovi_classi_job_test.rb`)

**Contesto (rischio ALTO):** oggi `promuovi_primaria!` fa DUE cose: (1) identità classi EE (scorrimento 1ª→5ª, merge/split, spostamenti insegnanti — logica di dominio insostituibile) e (2) costruzione adozioni (`costruisci_adozioni!` con match su `*_origine`). Il design vuole che (2) sia scritta SOLO dal `Adozione::Reconciler` (già sorgente unica set-based dalla Fase 1). Mantieni (1) invariato; sostituisci (2) con una chiamata al Reconciler scoped alla provincia della scuola.

**Step 1: Write the characterization test**

```ruby
# Cattura lo stato attuale PRIMA di rifattorizzare: dopo promuovi_primaria!,
# la scuola ha le classi del nuovo anno con le adozioni EE da_acquistare corrette.
test "promuovi_primaria! crea le adozioni del nuovo anno come oggi" do
  # setup snapshot MIUR EE per la scuola, classi anno da; poi promuovi
  scuola.promuovi_primaria!(da: "202526", a: "202627")
  adozioni = scuola.adozioni.joins(:classe).where(classi: { anno_scolastico: "202627" })
  assert adozioni.exists?
  # snapshot dei conteggi per confronto post-refactor
  @conteggio_atteso = adozioni.count
end
```

**Step 2: Run to establish baseline**

Run: `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n /promuovi_primaria/`
Expected: PASS (baseline verde con l'implementazione attuale)

**Step 3: Sostituisci la costruzione adozioni con il Reconciler**

Dopo aver costruito/allineato le classi in `promuovi_primaria!`, rimuovi la chiamata a
`costruisci_adozioni!` e delega:

```ruby
Adozione::Reconciler.new(account: account, provincia: provincia, anno: a).call
```

(Il Reconciler è idempotente e set-based: allinea adozioni alle classi già create,
preservando dati utente. Verifica che `provincia` sia disponibile su `self`.)

**Step 4: Run to verify equivalence**

Run: `docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n /promuovi_primaria/`
Expected: PASS con lo stesso conteggio adozioni del baseline.

**Step 5: Rimuovi `costruisci_adozioni!` se non più referenziato**

Run: `grep -rn "costruisci_adozioni" app` — se zero occorrenze, cancella il metodo.

**Step 6: Commit**

```bash
git add app/models/scuola.rb app/jobs/scuola_promuovi_classi_job.rb test/models/scuola_test.rb
git commit -m "refactor(passaggio-anno): promuovi_primaria! delega le adozioni al Reconciler"
```

---

## Task 5: Variante disciplina RELIGIONE / ATTIVITA' ALTERNATIVA

**Files:**
- Modify: `lib/tasks/miur.rake:391-400` (`cambia_religione`)
- Test: `test/tasks/miur_cambia_religione_test.rb` (o test del modello se estratto)

**Contesto:** `cambia_religione` copre `annocorso ["2","3","5"]` e le discipline `RELIGIONE`,
`ADOZIONE ALTERNATIVA ART. 156 …` (2 varianti con/senza spazio). Le 3 righe scoperte sono
la disciplina `RELIGIONE CATTOLICA` e `ATTIVITA' ALTERNATIVA` (grafie che il MIUR usa in
alcune regioni). Aggiungi le grafie mancanti all'elenco `disciplina: [...]`.

**Step 1: Write the failing test**

```ruby
test "cambia_religione copre anche RELIGIONE CATTOLICA e ATTIVITA' ALTERNATIVA" do
  # crea 3 righe miur_adozioni EE annocorso 2 con quelle discipline
  # esegui il task/metodo
  # asserisci che sono state normalizzate come le altre religioni
end
```

**Step 2: Run to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/tasks/miur_cambia_religione_test.rb`
Expected: FAIL (le 3 righe non vengono toccate)

**Step 3: Aggiungi le grafie mancanti**

Estendi l'array `disciplina: [...]` con `"RELIGIONE CATTOLICA"`, `"ATTIVITA' ALTERNATIVA"`
(e le eventuali varianti con spazio finale, come già fatto per le altre).

**Step 4: Run to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/tasks/miur_cambia_religione_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/tasks/miur.rake test/tasks/miur_cambia_religione_test.rb
git commit -m "fix(miur): cambia_religione copre RELIGIONE CATTOLICA e ATTIVITA' ALTERNATIVA"
```

---

## Task 6: Verifica finale e pulizia

**Step 1: Suite completa controllo_adozioni + passaggio anno + reconciler**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/models/adozione test/models/scuola_test.rb test/controllers/controllo_adozioni_controller_test.rb test/jobs`
Expected: tutto verde.

**Step 2: Grep anti-duplicazione**

Run: `grep -rn "promuovibil" app/models/controllo_adozioni` — deve restare in **un solo** file (`classificazione.rb`); Dashboard/PassaggioAnno lo interpolano, non lo ridefiniscono.

**Step 3: Aggiorna la memoria di progetto**

Segna in `project_miur_sync_design.md` che la Fase 2 "Logica" è fatta: Classificazione unica, AnnoScolastico, promuovi_primaria! delega, religione. Restano: track Stat + drop viste ponte, Fase 4 anagrafe.

**Step 4: Commit finale**

```bash
git commit -am "chore(controllo-adozioni): Fase 2 logica completata"
```

---

## Riepilogo fasi (dopo questo piano)

- ✅ **Fase 1 Fondamenta** — tabelle `miur_*`, backfill, swap, consumer.
- 🔵 **Fase 3 UI** — riga stato-centrica + merge dashboard/index (fatta 2026-07-07); resta opzionale: show ricca, controller REST dedicati per le 4 azioni massive.
- ⬜ **Fase 2 Logica** — QUESTO PIANO.
- ⬜ **Track Stat cleanup** — riscrivere 49/41/32 Stat su `miur_*`, poi drop `new_adozioni`/`new_scuole`/`import_adozioni`.
- ⬜ **Fase 4 Anagrafe** — `import_scuole` → `miur_anagrafe_scuole`.
