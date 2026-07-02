# Reconcile builder set-based (Sezione 2) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sostituire il fan-out da 16k `ScuolaPromuoviClassiJob` con un builder
**set-based idempotente** che ricostruisce `classi`+`adozioni` storicizzate (202526
da `import_adozioni`, 202627 da `new_adozioni`) per account, scopato per provincia.

**Architecture:** Un PORO di dominio `Adozione::Reconciler.new(account:, provincia:,
anno:).call` in `app/models/adozione/` (stesso pattern di `ControlloAdozioni::Rebuild`:
niente app/services). Fasi SQL set-based in **una transazione con advisory lock**
(riattiva classi → upsert classi → archivia orfane → upsert adozioni → cancella
orfane protette), poi ricalcolo flag+counter fuori transazione via
`Adozione::Ricalcolo` (estratto da `UpdateScuolaMieAdozioniJob`). Idempotente via
`WHERE NOT EXISTS` (classi) e `ON CONFLICT DO NOTHING` (adozioni). Jobs sottili:
`ReconcileAdozioniJob` (coda `bulk`, uno per provincia) e orchestratore
`ReconcileAccountJob`; entry point di dominio `Account#reconcile_adozioni_later`
(convenzione `_later`). Nessuna migration: si riusano gli indici esistenti.

**Tech Stack:** Rails 8.1, PostgreSQL, ActiveRecord raw SQL (`sanitize_sql`),
Minitest + fixtures. Comandi in Docker: `docker exec prova-app-1 bin/rails ...`.

**Riferimento design:** `docs/plans/2026-07-02-editore-reconcile-assegnazione-design.md`

---

## Note di dominio (leggere prima)

- **Sorgenti** (colonne diverse!):
  - `new_adozioni` (a.s. `202627`, `stato` classe = `attiva`): colonne LOWERCASE
    `codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, daacquist,
    titolo, editore, autori, disciplina, prezzo, nuovaadoz, consigliato`.
    Booleano "sì" = `<col> ILIKE 'S%'`.
  - `import_adozioni` (a.s. `202526`, `stato` classe = `archiviata`): colonne
    UPPERCASE tra virgolette `"CODICESCUOLA","ANNOCORSO","SEZIONEANNO",
    "COMBINAZIONE","CODICEISBN","DAACQUIST","TITOLO","EDITORE","AUTORI",
    "DISCIPLINA","PREZZO","NUOVAADOZ","CONSIGLIATO"`. Booleano "sì" = `<col> = 'Si'`.
- **Match classe→scuola:** `classi.codice_ministeriale_origine = source.codicescuola`
  e `scuole.account_id = :account_id AND scuole.provincia = :provincia`.
- **Match adozione→classe:** `[codicescuola, annocorso, sezioneanno, combinazione]`
  → `classi.[codice_ministeriale_origine, anno_corso, sezione, combinazione]`,
  `classi.anno_scolastico = :anno`. **Il match vale anche per il DELETE degli
  orfani** (via `cl`, non solo `a.codicescuola+anno_corso`: altrimenti un ISBN
  rimosso dalla 1B ma presente in 1A non verrebbe mai cancellato dalla 1B).
- **Idempotenza classi:** l'unique index attivo è PARZIALE (`WHERE stato='attiva'`),
  non copre le archiviate → **NON** usare `ON CONFLICT` per le classi. Usare
  `INSERT ... SELECT ... WHERE NOT EXISTS (...)` (robusto per entrambi gli anni)
  **e serializzare con advisory lock** (senza unique index sulle archiviate, due
  run concorrenti sulla stessa provincia duplicherebbero righe — precedente:
  `ControlloAdozioni::Rebuild::LOCK_KEY`).
- **Idempotenza adozioni:** unique index `index_adozioni_on_classe_isbn_anno`
  `(classe_id, codice_isbn, anno_scolastico)` copre tutti gli stati → `ON CONFLICT
  (classe_id, codice_isbn, anno_scolastico) DO NOTHING`. Il DO NOTHING **preserva
  le righe esistenti** (note, numero_copie, mia, libro_id): scelta deliberata
  pro-produzione, il reconcile non riscrive lo snapshot di righe già presenti.
- **Dati production — DELETE protetto:** `DELETE FROM adozioni` raw **bypassa**
  `dependent: :destroy` su `consegne_saggio` (`adozione.rb`). Un'adozione orfana
  si cancella SOLO se: nessuna `consegne_saggio` collegata, `numero_copie` 0/NULL,
  `note` NULL. Le protette restano e si logga il conteggio (no silent cap).
- **Attive di anni precedenti (scoperto sul run pilota):** l'indice unico
  parziale sulle attive NON include `anno_scolastico` → una classe attiva
  202526 di una scuola mai promossa collide con l'insert della 202627. Fase
  `archivia_anni_precedenti` (prima di tutte, solo anno corrente): archivia le
  attive scoped con `anno_scolastico IS DISTINCT FROM :anno` — è ciò che
  faceva la promozione per-scuola. In BOLOGNA erano 588.
  **MA solo per le scuole presenti nella sorgente corrente** (scoperto su
  REEE813027): le scuole in attesa del rilascio cumulativo MIUR (assenti da
  `new_adozioni`) tengono le classi vecchie attive, altrimenti `adozioni_count`
  va a 0 e spariscono dalla panoramica (`con_adozioni?` richiede counter > 0 o
  presenza nel MIUR). Stessa semantica della promozione: promuovibile ⇒ nel MIUR.
- **Classi che ricompaiono:** il rilascio MIUR è cumulativo — una classe archiviata
  come orfana può ritornare in sorgente. Serve la fase `riattiva_classi` (solo anno
  corrente), PRIMA dell'upsert, così il `NOT EXISTS` la trova già attiva e non duplica.
- **Scope anagrafe scuole:** FUORI da questo piano. Il reconcile assume le `scuole`
  già presenti (caricate dall'import zone). Ricostruisce solo classi/adozioni.
- **NULL-safe:** `combinazione` può essere NULL → confronti con `IS NOT DISTINCT FROM`.
- **Prezzo:** riusare l'idioma già collaudato di `ControlloAdozioni::Rebuild`
  (regex POSIX + `round(numeric * 100)::int`): il cast `::float * 100` del piano
  precedente crasha su prezzi non numerici e ha rounding float.
- **Flag + counter:** dopo il reconcile le adozioni nuove hanno `mia: false` →
  ricalcolare **sia** mia/disdetta **sia** i counter, estraendo TUTTA la logica di
  `UpdateScuolaMieAdozioniJob` (reset flag, set mia, set disdetta, update_counters)
  in `Adozione::Ricalcolo`, scoped su `scuola_ids`.
- **Test:** fixtures per account (`accounts(:fizzy)`, come i job test esistenti);
  la scuola e le righe sorgente si creano nel setup con codici sintetici, per
  isolare dalla fixture `new_adozioni` condivisa. Asserzioni scoped a `@scuola`
  (non conteggi globali). Si testa la API pubblica (`call`), MAI `send(:privato)`:
  le fasi non ancora implementate sono no-op, quindi ogni task asserisce il
  comportamento cumulativo di `call`.

---

## Task 1: Source descriptor + skeleton `Adozione::Reconciler`

**Files:**
- Create: `app/models/adozione/reconciler.rb`
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
# test/models/adozione/reconciler_test.rb
require "test_helper"

class Adozione::ReconcilerTest < ActiveSupport::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    @scuola = @account.scuole.create!(codice_ministeriale: "XXEE00001A",
      provincia: "XX", comune: "TESTVILLE", denominazione: "Plesso Reconcile",
      tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
  end

  # Righe sorgente con codice sintetico "XX...": non collidono con le fixture
  # new_adozioni condivise, e la provincia "XX" isola il reconcile.
  def seed_new_adozioni(rows)
    rows.each { |r| NewAdozione.create!({ tipogradoscuola: "EE" }.merge(r)) }
  end

  def reconciler(anno: "202627")
    Adozione::Reconciler.new(account: @account, provincia: "XX", anno: anno)
  end

  test "source mappa anno su tabella e stato" do
    assert_equal "new_adozioni", reconciler.source.table
    assert_equal "attiva", reconciler.source.stato
    src = reconciler(anno: "202526").source
    assert_equal "import_adozioni", src.table
    assert_equal "archiviata", src.stato
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: FAIL — `uninitialized constant Adozione::Reconciler`.

**Step 3: Write minimal implementation**

```ruby
# app/models/adozione/reconciler.rb
class Adozione::Reconciler
  # Ricostruzione set-based idempotente di classi/adozioni storicizzate per
  # (account, provincia, anno). Sostituisce il fan-out per-scuola.
  # Stesso pattern di ControlloAdozioni::Rebuild: transazione + advisory lock.

  # col: nome_logico → identificatore SQL (già quotato per import_adozioni).
  # si: espressione booleana "vale sì" per la colonna passata.
  Source = Struct.new(:table, :col, :stato, :si, keyword_init: true)

  # Prezzo stringa "12,34" -> cents int (0 se non numerico). Idioma da
  # ControlloAdozioni::Rebuild::PREZZO_CENTS: classi POSIX, round su numeric.
  PREZZO_CENTS = "CASE WHEN replace(src.prezzo, ',', '.') ~ '^[0-9]+([.][0-9]+)?$' " \
                 "THEN round(replace(src.prezzo, ',', '.')::numeric * 100)::int " \
                 "ELSE 0 END".freeze

  NEW = Source.new(
    table: "new_adozioni", stato: "attiva",
    si: ->(expr) { "COALESCE(#{expr}, '') ILIKE 'S%'" },
    col: { codicescuola: "codicescuola", annocorso: "annocorso",
           sezioneanno: "sezioneanno", combinazione: "combinazione",
           codiceisbn: "codiceisbn", daacquist: "daacquist", titolo: "titolo",
           editore: "editore", autori: "autori", disciplina: "disciplina",
           prezzo: "prezzo", nuovaadoz: "nuovaadoz", consigliato: "consigliato" }
  ).freeze

  IMPORT = Source.new(
    table: "import_adozioni", stato: "archiviata",
    si: ->(expr) { "#{expr} = 'Si'" },
    col: { codicescuola: %q{"CODICESCUOLA"}, annocorso: %q{"ANNOCORSO"},
           sezioneanno: %q{"SEZIONEANNO"}, combinazione: %q{"COMBINAZIONE"},
           codiceisbn: %q{"CODICEISBN"}, daacquist: %q{"DAACQUIST"},
           titolo: %q{"TITOLO"}, editore: %q{"EDITORE"}, autori: %q{"AUTORI"},
           disciplina: %q{"DISCIPLINA"}, prezzo: %q{"PREZZO"},
           nuovaadoz: %q{"NUOVAADOZ"}, consigliato: %q{"CONSIGLIATO"} }
  ).freeze

  def initialize(account:, provincia:, anno:)
    @account = account
    @provincia = provincia
    @anno = anno.to_s
  end

  def source
    @anno == "202627" ? NEW : IMPORT
  end

  def call
    ApplicationRecord.transaction do
      exec_sql("SELECT pg_advisory_xact_lock(hashtext(:lock_key))",
               lock_key: "reconcile/#{account.id}/#{provincia}/#{anno}")
      riattiva_classi
      upsert_classi
      archivia_classi_orfane
      upsert_adozioni
      cancella_adozioni_orfane
    end
    ricalcola
  end

  private

  attr_reader :account, :provincia, :anno

  def params
    { account_id: account.id, provincia: provincia, anno: anno }
  end

  def exec_sql(sql, extra = {})
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([sql, params.merge(extra)])
    )
  end

  def riattiva_classi          = nil
  def upsert_classi            = nil
  def archivia_classi_orfane   = nil
  def upsert_adozioni          = nil
  def cancella_adozioni_orfane = nil
  def ricalcola                = nil
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/adozione/reconciler.rb test/models/adozione/reconciler_test.rb
git commit -m "feat(reconciler): source descriptor + skeleton Adozione::Reconciler"
```

---

## Task 2: Upsert classi (idempotente via NOT EXISTS)

**Files:**
- Modify: `app/models/adozione/reconciler.rb` (metodo `upsert_classi`)
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing test** (via `call`: le altre fasi sono no-op)

```ruby
test "call crea le classi distinte e non duplica su re-run" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "111", daacquist: "Si" },
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "222", daacquist: "Si" },
    { codicescuola: "XXEE00001A", annocorso: "2", sezioneanno: "B", combinazione: nil, codiceisbn: "333", daacquist: "No" }
  ])

  assert_difference -> { @scuola.classi.where(anno_scolastico: "202627").count }, 2 do
    reconciler.call
  end
  c = @scuola.classi.find_by(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
  assert_equal "attiva", c.stato
  assert_equal "XXEE00001A", c.codice_ministeriale_origine

  # idempotente
  assert_no_difference -> { @scuola.classi.count } do
    reconciler.call
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb -n /crea_le_classi/`
Expected: FAIL — `+2` atteso, `0` reale (fase è no-op).

**Step 3: Write minimal implementation**

```ruby
def upsert_classi
  s = source
  c = s.col
  sql = <<~SQL
    INSERT INTO classi
      (id, account_id, scuola_id, anno_corso, sezione, combinazione,
       anno_scolastico, stato, tipo_scuola,
       codice_ministeriale_origine, classe_origine, sezione_origine, combinazione_origine,
       created_at, updated_at)
    SELECT gen_random_uuid(), :account_id, sc.id,
           src.annocorso, src.sezioneanno, src.combinazione,
           :anno, '#{s.stato}', sc.tipo_scuola,
           src.codicescuola, src.annocorso, src.sezioneanno, src.combinazione,
           now(), now()
    FROM (
      SELECT DISTINCT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
             #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione
      FROM #{s.table}
    ) src
    JOIN scuole sc ON sc.codice_ministeriale = src.codicescuola
      AND sc.account_id = :account_id AND sc.provincia = :provincia
    WHERE NOT EXISTS (
      SELECT 1 FROM classi cl
      WHERE cl.scuola_id = sc.id
        AND cl.anno_scolastico = :anno
        AND cl.anno_corso IS NOT DISTINCT FROM src.annocorso
        AND cl.sezione IS NOT DISTINCT FROM src.sezioneanno
        AND cl.combinazione IS NOT DISTINCT FROM src.combinazione
    )
  SQL
  exec_sql(sql)
end
```

> Nota: `#{s.stato}` e `#{c[...]}` sono interpolazioni di costanti frozen della
> classe (mai input utente) → sicuro. I valori runtime (`:account_id`,
> `:provincia`, `:anno`) restano bind params via `sanitize_sql`.

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb -n /crea_le_classi/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): upsert classi idempotente"
```

---

## Task 3: Archivia classi orfane + riattiva ricomparse (solo anno corrente)

**Files:**
- Modify: `app/models/adozione/reconciler.rb` (`archivia_classi_orfane`, `riattiva_classi`)
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing tests**

```ruby
test "call archivia le classi attive non piu in sorgente (solo 202627)" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "111", daacquist: "Si" }
  ])
  # classe attiva non presente in sorgente
  orfana = @account.classi.create!(scuola: @scuola, anno_scolastico: "202627",
    anno_corso: "5", sezione: "Z", stato: "attiva",
    codice_ministeriale_origine: "XXEE00001A", classe_origine: "5", sezione_origine: "Z")

  reconciler.call
  assert_equal "archiviata", orfana.reload.stato
  assert_equal "attiva", @scuola.classi.find_by(anno_corso: "1", sezione: "A").stato
end

test "call riattiva una classe archiviata che ricompare in sorgente" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "111", daacquist: "Si" }
  ])
  ricomparsa = @account.classi.create!(scuola: @scuola, anno_scolastico: "202627",
    anno_corso: "1", sezione: "A", stato: "archiviata",
    codice_ministeriale_origine: "XXEE00001A", classe_origine: "1", sezione_origine: "A")

  assert_no_difference -> { @scuola.classi.count } do   # riattiva, non duplica
    reconciler.call
  end
  assert_equal "attiva", ricomparsa.reload.stato
end
```

**Step 2: Run tests to verify they fail**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: FAIL — orfana ancora `attiva`; ricomparsa ancora `archiviata`.

**Step 3: Write minimal implementation**

```ruby
# Le due fasi girano solo per l'anno corrente: lo storico 202526 nasce e resta archiviato.

def riattiva_classi
  return unless source.stato == "attiva"

  exec_sql(<<~SQL)
    UPDATE classi cl SET stato = 'attiva', updated_at = now()
    FROM scuole sc
    WHERE cl.scuola_id = sc.id
      AND sc.account_id = :account_id AND sc.provincia = :provincia
      AND cl.anno_scolastico = :anno
      AND cl.stato = 'archiviata'
      AND EXISTS (#{sorgente_match_classe})
  SQL
end

def archivia_classi_orfane
  return unless source.stato == "attiva"

  exec_sql(<<~SQL)
    UPDATE classi cl SET stato = 'archiviata', updated_at = now()
    FROM scuole sc
    WHERE cl.scuola_id = sc.id
      AND sc.account_id = :account_id AND sc.provincia = :provincia
      AND cl.anno_scolastico = :anno
      AND cl.stato = 'attiva'
      AND NOT EXISTS (#{sorgente_match_classe})
  SQL
end

# Subquery riusata da riattiva/archivia/delete: la classe esiste in sorgente?
def sorgente_match_classe
  c = source.col
  <<~SQL
    SELECT 1 FROM #{source.table} src_m
    WHERE src_m.#{c[:codicescuola]} = cl.codice_ministeriale_origine
      AND src_m.#{c[:annocorso]}    IS NOT DISTINCT FROM cl.anno_corso
      AND src_m.#{c[:sezioneanno]}  IS NOT DISTINCT FROM cl.sezione
      AND src_m.#{c[:combinazione]} IS NOT DISTINCT FROM cl.combinazione
  SQL
end
```

> Attenzione: per `import_adozioni` gli identificatori in `col` sono già quotati
> (`"CODICESCUOLA"`), quindi il prefisso va composto come `src_m.#{c[:...]}` —
> verificare che produca `src_m."CODICESCUOLA"` (valido in PG).

**Step 4: Run tests to verify they pass**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): archivia orfane e riattiva ricomparse (anno corrente)"
```

---

## Task 4: Upsert adozioni (ON CONFLICT DO NOTHING)

**Files:**
- Modify: `app/models/adozione/reconciler.rb` (`upsert_adozioni`)
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "call crea snapshot adozioni con anno_scolastico+codicescuola, idempotente" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", nuovaadoz: "Si", consigliato: "No",
      titolo: "Libro Uno", editore: "Giunti", prezzo: "12,50" },
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "222", daacquist: "No", titolo: "Libro Due", editore: "Giunti", prezzo: "n.d." }
  ])

  assert_difference -> { @account.adozioni.where(anno_scolastico: "202627").count }, 2 do
    reconciler.call
  end
  a = @account.adozioni.find_by(codice_isbn: "111", anno_scolastico: "202627")
  assert_equal "XXEE00001A", a.codicescuola
  assert a.da_acquistare
  assert a.nuova_adozione
  assert_not a.consigliato
  assert_equal 1250, a.prezzo_cents

  b = @account.adozioni.find_by(codice_isbn: "222", anno_scolastico: "202627")
  assert_equal 0, b.prezzo_cents   # prezzo non numerico -> 0, non crash

  assert_no_difference -> { @account.adozioni.where(anno_scolastico: "202627").count } do
    reconciler.call
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb -n /snapshot/`
Expected: FAIL — `+2` atteso, `0` reale.

**Step 3: Write minimal implementation**

```ruby
def upsert_adozioni
  s = source
  c = s.col
  sql = <<~SQL
    INSERT INTO adozioni
      (id, account_id, classe_id, codice_isbn, anno_scolastico, anno_corso, codicescuola,
       titolo, editore, autori, disciplina, prezzo_cents,
       nuova_adozione, da_acquistare, consigliato, created_at, updated_at)
    SELECT gen_random_uuid(), :account_id, cl.id, src.codiceisbn, :anno, src.annocorso, src.codicescuola,
       src.titolo, src.editore, src.autori, src.disciplina,
       #{PREZZO_CENTS},
       #{s.si.call('src.nuovaadoz')},
       #{s.si.call('src.daacquist')},
       #{s.si.call('src.consigliato')},
       now(), now()
    FROM (
      SELECT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
             #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione,
             #{c[:codiceisbn]} AS codiceisbn, #{c[:daacquist]} AS daacquist,
             #{c[:titolo]} AS titolo, #{c[:editore]} AS editore,
             #{c[:autori]} AS autori, #{c[:disciplina]} AS disciplina,
             #{c[:prezzo]} AS prezzo, #{c[:nuovaadoz]} AS nuovaadoz,
             #{c[:consigliato]} AS consigliato
      FROM #{s.table}
    ) src
    JOIN scuole sc ON sc.codice_ministeriale = src.codicescuola
      AND sc.account_id = :account_id AND sc.provincia = :provincia
    JOIN classi cl ON cl.scuola_id = sc.id AND cl.anno_scolastico = :anno
      AND cl.anno_corso IS NOT DISTINCT FROM src.annocorso
      AND cl.sezione IS NOT DISTINCT FROM src.sezioneanno
      AND cl.combinazione IS NOT DISTINCT FROM src.combinazione
    WHERE src.codiceisbn IS NOT NULL
    ON CONFLICT (classe_id, codice_isbn, anno_scolastico) DO NOTHING
  SQL
  exec_sql(sql)
end
```

> La subquery `src` normalizza i nomi colonna (lower/UPPER) UNA volta; da lì in
> poi il SQL è identico per le due sorgenti. I booleani passano dalla lambda
> `si` del descriptor (niente `gsub` fragili).

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb -n /snapshot/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): upsert adozioni snapshot idempotente"
```

---

## Task 5: Cancella adozioni orfane (protette per dati production)

**Files:**
- Modify: `app/models/adozione/reconciler.rb` (`cancella_adozioni_orfane`)
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing tests**

```ruby
test "call rimuove le adozioni dell'anno non piu in sorgente" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
  ])
  reconciler.call
  classe = @scuola.classi.find_by(anno_corso: "1", sezione: "A")
  orfana = @account.adozioni.create!(classe: classe, codice_isbn: "999",
    anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", da_acquistare: true)

  reconciler.call
  assert_nil Adozione.find_by(id: orfana.id)
  assert @account.adozioni.exists?(codice_isbn: "111", anno_scolastico: "202627")
end

test "call NON rimuove orfane con dati utente (note, copie, consegne saggio)" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
  ])
  reconciler.call
  classe = @scuola.classi.find_by(anno_corso: "1", sezione: "A")
  con_note = @account.adozioni.create!(classe: classe, codice_isbn: "888",
    anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", note: "vista a scuola")
  con_copie = @account.adozioni.create!(classe: classe, codice_isbn: "777",
    anno_scolastico: "202627", codicescuola: "XXEE00001A", anno_corso: "1", numero_copie: 3)

  reconciler.call
  assert Adozione.exists?(id: con_note.id)
  assert Adozione.exists?(id: con_copie.id)
end
```

**Step 2: Run tests to verify they fail**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: FAIL — nessuna riga cancellata (primo test).

**Step 3: Write minimal implementation**

```ruby
# DELETE raw: bypassa dependent: :destroy — per questo le orfane con dati utente
# (consegne_saggio, numero_copie, note) NON si toccano. Il match sorgente passa
# dalla classe (sezione/combinazione comprese), non dal solo codicescuola+anno.
def cancella_adozioni_orfane
  s = source
  c = s.col
  sql = <<~SQL
    DELETE FROM adozioni a
    USING classi cl, scuole sc
    WHERE a.classe_id = cl.id AND cl.scuola_id = sc.id
      AND sc.account_id = :account_id AND sc.provincia = :provincia
      AND a.anno_scolastico = :anno
      AND NOT EXISTS (
        SELECT 1 FROM #{s.table} src_m
        WHERE src_m.#{c[:codicescuola]} = cl.codice_ministeriale_origine
          AND src_m.#{c[:annocorso]}    IS NOT DISTINCT FROM cl.anno_corso
          AND src_m.#{c[:sezioneanno]}  IS NOT DISTINCT FROM cl.sezione
          AND src_m.#{c[:combinazione]} IS NOT DISTINCT FROM cl.combinazione
          AND src_m.#{c[:codiceisbn]}   = a.codice_isbn
      )
      AND NOT EXISTS (SELECT 1 FROM consegne_saggio cs WHERE cs.adozione_id = a.id)
      AND COALESCE(a.numero_copie, 0) = 0
      AND a.note IS NULL
  SQL
  result = exec_sql(sql)
  log_protette if result.cmd_tuples >= 0  # vedi Step 3b
end
```

**Step 3b:** aggiungere un log (Rails.logger.info) con il conteggio delle orfane
protette (stessa query con SELECT COUNT e le condizioni di protezione invertite),
così in produzione il "non cancellato" è visibile e non un silent skip.

**Step 4: Run tests to verify they pass**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): cancella adozioni orfane con protezione dati utente"
```

---

## Task 6: `Adozione::Ricalcolo` (mia/disdetta + counter) + integrazione `call`

**Files:**
- Create: `app/models/adozione/ricalcolo.rb`
- Modify: `app/models/adozione/reconciler.rb` (`ricalcola`)
- Modify: `app/jobs/update_scuola_mie_adozioni_job.rb` (delega)
- Test: `test/models/adozione/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "call end-to-end aggiorna i counter della scuola" do
  seed_new_adozioni([
    { codicescuola: "XXEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", prezzo: "10,00" },
    { codicescuola: "XXEE00001A", annocorso: "2", sezioneanno: "B", combinazione: nil,
      codiceisbn: "222", daacquist: "Si", prezzo: "10,00" }
  ])
  reconciler.call
  @scuola.reload
  assert_equal 2, @scuola.classi_count
  assert_equal 2, @scuola.adozioni_count
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb -n /end_to_end/`
Expected: FAIL — `classi_count` 0.

**Step 3: Write minimal implementation**

Le adozioni appena inserite nascono `mia: false`: ricalcolare solo i counter non
basta (`mie_adozioni_count` resterebbe 0 anche dove i mandati coprono). Estrarre
da `UpdateScuolaMieAdozioniJob` TUTTA la parte set-based (reset flag → set mia →
set disdetta → i 6 UPDATE counter) in:

```ruby
# app/models/adozione/ricalcolo.rb
class Adozione::Ricalcolo
  def initialize(account:, scuola_ids:)
    @account = account
    @scuola_ids = scuola_ids
  end

  def call
    return if @scuola_ids.empty?
    reset_flags
    set_mia
    set_disdetta
    update_counters
  end
  # ... SQL spostato 1:1 dal job (stessi statement, stessi bind); helper execute privato
end
```

`UpdateScuolaMieAdozioniJob#perform` delega a
`Adozione::Ricalcolo.new(account:, scuola_ids:).call` e conserva SOLO la raccolta
degli scuola_ids (direzione+plessi) e il broadcast. Spostamento 1:1, nessuna
"miglioria" al SQL. Poi:

```ruby
def ricalcola
  scuola_ids = account.scuole.where(provincia: provincia).pluck(:id)
  Adozione::Ricalcolo.new(account: account, scuola_ids: scuola_ids).call
end
```

**Step 4: Run tests to verify they pass**

Run: `docker exec prova-app-1 bin/rails test test/models/adozione/reconciler_test.rb`
Expected: tutti PASS. Poi i test esistenti del job:
`docker exec prova-app-1 bin/rails test test/jobs/update_mie_adozioni_job_test.rb test/jobs/update_scuole_counters_job_test.rb`
Expected: PASS (nessuna regressione dalla delega).

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): Adozione::Ricalcolo (mia/disdetta+counter) e delega dal job"
```

---

## Task 7: `ReconcileAdozioniJob` (wrapper per provincia)

**Files:**
- Create: `app/jobs/reconcile_adozioni_job.rb`
- Test: `test/jobs/reconcile_adozioni_job_test.rb`

**Step 1: Write the failing test** (integrazione reale, niente stub)

```ruby
# test/jobs/reconcile_adozioni_job_test.rb
require "test_helper"

class ReconcileAdozioniJobTest < ActiveJob::TestCase
  fixtures :accounts

  test "usa la coda bulk" do
    assert_equal "bulk", ReconcileAdozioniJob.new.queue_name
  end

  test "esegue il reconcile per la provincia" do
    account = accounts(:fizzy)
    scuola = account.scuole.create!(codice_ministeriale: "XXEE00002B",
      provincia: "XX", tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
    NewAdozione.create!(tipogradoscuola: "EE", codicescuola: "XXEE00002B",
      annocorso: "1", sezioneanno: "A", codiceisbn: "111", daacquist: "Si")

    ReconcileAdozioniJob.perform_now(account, provincia: "XX", anno: "202627")

    assert scuola.classi.exists?(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/jobs/reconcile_adozioni_job_test.rb`
Expected: FAIL — `uninitialized constant ReconcileAdozioniJob`.

**Step 3: Write minimal implementation**

```ruby
# app/jobs/reconcile_adozioni_job.rb
class ReconcileAdozioniJob < ApplicationJob
  # :bulk come gli altri job di massa (vedi UpdateScuolaMieAdozioniJob):
  # decine di job per account, fuori dalla coda interattiva.
  queue_as :bulk

  def perform(account, provincia:, anno:)
    Current.account = account
    Adozione::Reconciler.new(account: account, provincia: provincia, anno: anno).call
  end
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/jobs/reconcile_adozioni_job_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: ReconcileAdozioniJob (coda bulk, per provincia)"
```

---

## Task 8: `ReconcileAccountJob` + `Account#reconcile_adozioni_later`

**Files:**
- Create: `app/jobs/reconcile_account_job.rb`
- Modify: `app/models/account.rb` (metodo `reconcile_adozioni_later`)
- Test: `test/jobs/reconcile_account_job_test.rb`

**Step 1: Write the failing test**

```ruby
# test/jobs/reconcile_account_job_test.rb
require "test_helper"

class ReconcileAccountJobTest < ActiveJob::TestCase
  fixtures :accounts

  setup do
    @account = accounts(:fizzy)
    @account.scuole.create!(codice_ministeriale: "XXEE1", provincia: "XX", grado: "E")
    @account.scuole.create!(codice_ministeriale: "YYEE1", provincia: "YY", grado: "E")
  end

  test "fa fan-out per provincia distinta x entrambi gli anni" do
    province = @account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia)

    assert_enqueued_jobs province.size * 2, only: ReconcileAdozioniJob do
      ReconcileAccountJob.perform_now(@account)
    end
  end

  test "account#reconcile_adozioni_later accoda l'orchestratore" do
    assert_enqueued_with job: ReconcileAccountJob, args: [@account] do
      @account.reconcile_adozioni_later
    end
  end
end
```

> Il numero di province viene dai dati (fixtures scuole comprese), non hardcoded
> a 4: il test resta stabile se le fixtures cambiano.

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/jobs/reconcile_account_job_test.rb`
Expected: FAIL — costante mancante.

**Step 3: Write minimal implementation**

```ruby
# app/jobs/reconcile_account_job.rb
class ReconcileAccountJob < ApplicationJob
  queue_as :bulk

  ANNI = %w[202526 202627].freeze

  def perform(account)
    account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia).each do |prov|
      ANNI.each { |anno| ReconcileAdozioniJob.perform_later(account, provincia: prov, anno: anno) }
    end
  end
end
```

```ruby
# app/models/account.rb — convenzione _later (Fizzy)
def reconcile_adozioni_later
  ReconcileAccountJob.perform_later(self)
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/jobs/reconcile_account_job_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: ReconcileAccountJob + Account#reconcile_adozioni_later"
```

---

## Task 9: Rake task per lanciarlo in produzione

**Files:**
- Create: `lib/tasks/reconcile.rake`

**Step 1: Implementazione**

```ruby
# lib/tasks/reconcile.rake
namespace :reconcile do
  desc "Ricostruzione set-based classi/adozioni per un account (ACCOUNT_ID=... [PROVINCIA=BO] [ANNO=202627])"
  task adozioni: :environment do
    account = Account.find(ENV.fetch("ACCOUNT_ID"))
    prov = ENV["PROVINCIA"].presence
    anno = ENV["ANNO"].presence

    if prov && anno
      Adozione::Reconciler.new(account: account, provincia: prov, anno: anno).call
      puts "Reconcile #{account.name} #{prov} #{anno}: OK"
    else
      account.reconcile_adozioni_later
      puts "Fan-out ReconcileAccountJob accodato per #{account.name}"
    end
  end
end
```

**Step 2: Verifica in dev (dry, poche province)**

Run:
```bash
docker exec prova-app-1 bin/rails "reconcile:adozioni" ACCOUNT_ID=<id> PROVINCIA=BO ANNO=202627
```
Expected: `Reconcile ... OK`, e i conteggi classi/adozioni 202627 di BO coerenti.

**Step 3: Commit**

```bash
git add -A && git commit -m "feat: rake reconcile:adozioni per lancio produzione"
```

---

## Task 10: Validazione manuale su bacherini (dev) + confronto

**Step 1:** Lancia il reconcile per una provincia già popolata dalla promozione e
confronta i conteggi PRIMA/DOPO (devono coincidere con la promozione, o essere
spiegabili):

```bash
docker exec prova-app-1 bin/rails runner '
acc = Account.find("1941ab59-04bd-4cfb-a297-7644e4bae743")
prov = "BO"
before = {
  classi:   acc.classi.attive.joins(:scuola).where(scuole: {provincia: prov}).count,
  adozioni: acc.adozioni.joins(classe: :scuola).where(anno_scolastico: "202627", scuole: {provincia: prov}).count
}
Adozione::Reconciler.new(account: acc, provincia: prov, anno: "202627").call
after = {
  classi:   acc.classi.attive.joins(:scuola).where(scuole: {provincia: prov}).count,
  adozioni: acc.adozioni.joins(classe: :scuola).where(anno_scolastico: "202627", scuole: {provincia: prov}).count
}
puts({before:, after:}.inspect)
'
```

**Step 2:** Rilancia (idempotenza): i conteggi non cambiano. Controlla nel log il
conteggio delle orfane protette (deve essere spiegabile: consegne saggio, note).

**Step 3:** `ANALYZE` dopo il run massivo (NON `VACUUM FULL` — shm 64MB):
```bash
docker exec prova-app-1 bin/rails runner 'ActiveRecord::Base.connection.execute("ANALYZE classi; ANALYZE adozioni;")'
```

---

## Produzione — checklist rollout

**Prima di tutto (dati production):** dump di sicurezza di `classi` e `adozioni`
dell'account editore (`pg_dump -t classi -t adozioni` o CSV via `\copy` scoped
account) — il reconcile cancella adozioni orfane, il backup rende reversibile.

1. Deploy del codice (job/service/rake).
2. Su una provincia pilota: `reconcile:adozioni ACCOUNT_ID=<bacherini> PROVINCIA=BO ANNO=202627`.
3. Verifica conteggi + idempotenza (ri-lancio) + log orfane protette.
4. Fan-out completo: `reconcile:adozioni ACCOUNT_ID=<bacherini>` (accoda per tutte
   le province × 2 anni sulla coda `bulk`).
5. Monitor coda `bulk` + temperatura (decine di job, non 16k).
6. `ANALYZE classi; ANALYZE adozioni;`.
6b. **`UpdateMieAdozioniJob.perform_later(account)`** — il reconcile imposta i
   flag `mia` e i counter delle scuole, ma NON `mandati.sezioni_count`
   (i counter di Zone/Mandati/Colleghi) né la creazione/link dei `Libro`:
   quelli li fa solo questo job. Senza, le province nuove restano senza counter.
7. **Dopo la validazione**: smettere di usare `PromuoviScuolePromuovibiliJob` per
   l'editore (la sostituzione UI è nella Sezione 4 del design).

## Cosa NON è in questo piano
- Anagrafe scuole (upsert `scuole`): resta all'import zone esistente.
- Fork admin/agente e dashboard analytics (Sezione 4).
- Assegnazione agenti (Sezione 3).
- Rimozione di `PromuoviScuolePromuovibiliJob` (dopo validazione, in Sezione 4).
- Aggiornamento snapshot di adozioni esistenti (titolo/prezzo cambiati in
  sorgente): `DO NOTHING` le lascia com'erano — accettato, eventuale `DO UPDATE`
  selettivo in un piano futuro se serve.
