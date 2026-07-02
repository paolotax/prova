# Reconcile builder set-based (Sezione 2) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sostituire il fan-out da 16k `ScuolaPromuoviClassiJob` con un builder
**set-based idempotente** che ricostruisce `classi`+`adozioni` storicizzate (202526
da `import_adozioni`, 202627 da `new_adozioni`) per account, scopato per provincia.

**Architecture:** Un service `Adozioni::Reconciler.new(account:, provincia:, anno:).call`
esegue 5 fasi SQL set-based (upsert classi → archivia classi orfane → upsert
adozioni → cancella adozioni orfane → ricalcola counter). Idempotente via
`WHERE NOT EXISTS` (classi) e `ON CONFLICT DO NOTHING` (adozioni). Un job
`ReconcileAdozioniJob` lo wrappa (coda `bulk`, uno per provincia); un orchestratore
`ReconcileAccountJob` fa fan-out per provincia × {202526, 202627} — decine di job,
non 16k. Nessuna migration: si riusano gli indici esistenti.

**Tech Stack:** Rails 8.1, PostgreSQL, ActiveRecord raw SQL (`sanitize_sql`),
Minitest + fixtures. Comandi in Docker: `docker exec prova-app-1 bin/rails ...`.

**Riferimento design:** `docs/plans/2026-07-02-editore-reconcile-assegnazione-design.md`

---

## Note di dominio (leggere prima)

- **Sorgenti** (colonne diverse!):
  - `new_adozioni` (a.s. `202627`, `stato` classe = `attiva`): colonne LOWERCASE
    `codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, daacquist,
    titolo, editore, autori, disciplina, prezzo, nuovaadoz, consigliato`.
    "da acquistare" = `daacquist ILIKE 'S%'`.
  - `import_adozioni` (a.s. `202526`, `stato` classe = `archiviata`): colonne
    UPPERCASE tra virgolette `"CODICESCUOLA","ANNOCORSO","SEZIONEANNO",
    "COMBINAZIONE","CODICEISBN","DAACQUIST","TITOLO","EDITORE","AUTORI",
    "DISCIPLINA","PREZZO","NUOVAADOZ","CONSIGLIATO"`. "da acquistare" = `"DAACQUIST" = 'Si'`.
- **Match classe→scuola:** `classi.codice_ministeriale_origine = source.codicescuola`
  e `scuole.account_id = :account_id AND scuole.provincia = :provincia`.
- **Match adozione→classe:** `[codicescuola, annocorso, sezioneanno, combinazione]`
  → `classi.[codice_ministeriale_origine, anno_corso, sezione, combinazione]`,
  `classi.anno_scolastico = :anno`.
- **Idempotenza classi:** l'unique index attivo è PARZIALE (`WHERE stato='attiva'`),
  non copre le archiviate 202526 → **NON** usare `ON CONFLICT` per le classi. Usare
  `INSERT ... SELECT ... WHERE NOT EXISTS (...)` (robusto per entrambi gli anni).
- **Idempotenza adozioni:** unique index `index_adozioni_on_classe_isbn_anno`
  `(classe_id, codice_isbn, anno_scolastico)` copre tutti gli stati → `ON CONFLICT
  (classe_id, codice_isbn, anno_scolastico) DO NOTHING`.
- **Scope anagrafe scuole:** FUORI da questo piano. Il reconcile assume le `scuole`
  già presenti (caricate dall'import zone). Ricostruisce solo classi/adozioni.
- **NULL-safe:** `combinazione` può essere NULL → confronti con `IS NOT DISTINCT FROM`.
- **Prezzo:** `(prezzo replace ',' '.')::float * 100` → `prezzo_cents` int.
- **Counter:** riusare la logica di `UpdateScuolaMieAdozioniJob#update_counters`
  (già set-based, scoped su `scuola_ids`).

Helper SQL condiviso (in tutti i service):

```ruby
def exec_sql(sql, params)
  ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql([sql, params]))
end
```

---

## Task 1: Source descriptor + skeleton Reconciler

**Files:**
- Create: `app/services/adozioni/reconciler.rb`
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
# test/services/adozioni/reconciler_test.rb
require "test_helper"

class Adozioni::ReconcilerTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Editore Test")
    @scuola = Scuola.create!(account: @account, codice_ministeriale: "BOEE00001A",
      provincia: "BO", comune: "BOLOGNA", denominazione: "Plesso Uno",
      tipo_scuola: "SCUOLA PRIMARIA", grado: "E")
  end

  def seed_new_adozioni(rows)
    rows.each { |r| NewAdozione.create!({ tipogradoscuola: "EE" }.merge(r)) }
  end

  test "source descriptor maps anno to table and stato" do
    src = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627").source
    assert_equal "new_adozioni", src.table
    assert_equal "attiva", src.stato
    src2 = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202526").source
    assert_equal "import_adozioni", src2.table
    assert_equal "archiviata", src2.stato
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /source_descriptor/`
Expected: FAIL — `uninitialized constant Adozioni::Reconciler`.

**Step 3: Write minimal implementation**

```ruby
# app/services/adozioni/reconciler.rb
module Adozioni
  # Ricostruzione set-based idempotente di classi/adozioni storicizzate per
  # (account, provincia, anno). Sostituisce il fan-out per-scuola.
  class Reconciler
    # col: mappa nome_logico → identificatore SQL (già quotato per import_adozioni).
    Source = Struct.new(:table, :col, :stato, :daacquist_sql, keyword_init: true)

    NEW = Source.new(
      table: "new_adozioni", stato: "attiva",
      daacquist_sql: "daacquist ILIKE 'S%'",
      col: { codicescuola: "codicescuola", annocorso: "annocorso",
             sezioneanno: "sezioneanno", combinazione: "combinazione",
             codiceisbn: "codiceisbn", titolo: "titolo", editore: "editore",
             autori: "autori", disciplina: "disciplina", prezzo: "prezzo",
             nuovaadoz: "nuovaadoz", consigliato: "consigliato" }
    ).freeze

    IMPORT = Source.new(
      table: "import_adozioni", stato: "archiviata",
      daacquist_sql: %q{"DAACQUIST" = 'Si'},
      col: { codicescuola: %q{"CODICESCUOLA"}, annocorso: %q{"ANNOCORSO"},
             sezioneanno: %q{"SEZIONEANNO"}, combinazione: %q{"COMBINAZIONE"},
             codiceisbn: %q{"CODICEISBN"}, titolo: %q{"TITOLO"}, editore: %q{"EDITORE"},
             autori: %q{"AUTORI"}, disciplina: %q{"DISCIPLINA"}, prezzo: %q{"PREZZO"},
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
      upsert_classi
      archivia_classi_orfane
      upsert_adozioni
      cancella_adozioni_orfane
      ricalcola_counter
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

    def upsert_classi        = nil
    def archivia_classi_orfane = nil
    def upsert_adozioni      = nil
    def cancella_adozioni_orfane = nil
    def ricalcola_counter    = nil
  end
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /source_descriptor/`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/services/adozioni/reconciler.rb test/services/adozioni/reconciler_test.rb
git commit -m "feat(reconciler): source descriptor + skeleton"
```

---

## Task 2: Upsert classi (idempotente via NOT EXISTS)

**Files:**
- Modify: `app/services/adozioni/reconciler.rb` (metodo `upsert_classi`)
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "upsert_classi crea le classi distinte e non duplica su re-run" do
  seed_new_adozioni([
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "111", daacquist: "Si" },
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "222", daacquist: "Si" },
    { codicescuola: "BOEE00001A", annocorso: "2", sezioneanno: "B", combinazione: nil, codiceisbn: "333", daacquist: "No" }
  ])
  r = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627")

  assert_difference -> { @account.classi.where(anno_scolastico: "202627").count }, 2 do
    r.send(:upsert_classi)
  end
  c = @account.classi.find_by(anno_scolastico: "202627", anno_corso: "1", sezione: "A")
  assert_equal "attiva", c.stato
  assert_equal "BOEE00001A", c.codice_ministeriale_origine
  assert_equal @scuola.id, c.scuola_id

  # idempotente
  assert_no_difference -> { @account.classi.where(anno_scolastico: "202627").count } do
    r.send(:upsert_classi)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /upsert_classi/`
Expected: FAIL — `+2` atteso, `0` reale (metodo è no-op).

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

> Nota: `#{s.stato}` e `#{c[...]}` sono interpolazioni di costanti hardcoded
> (mai input utente) → sicuro. I valori runtime (`:account_id`, `:provincia`,
> `:anno`) restano bind params via `sanitize_sql`.

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /upsert_classi/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): upsert classi idempotente"
```

---

## Task 3: Archivia classi orfane (solo anno corrente)

**Files:**
- Modify: `app/services/adozioni/reconciler.rb` (`archivia_classi_orfane`)
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "archivia_classi_orfane archivia le attive non piu in sorgente (solo 202627)" do
  seed_new_adozioni([
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil, codiceisbn: "111", daacquist: "Si" }
  ])
  r = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627")
  r.send(:upsert_classi)
  # classe attiva non presente in sorgente
  orfana = @account.classi.create!(scuola: @scuola, anno_scolastico: "202627",
    anno_corso: "5", sezione: "Z", stato: "attiva",
    codice_ministeriale_origine: "BOEE00001A", classe_origine: "5", sezione_origine: "Z")

  r.send(:archivia_classi_orfane)
  assert_equal "archiviata", orfana.reload.stato
  # la 1A resta attiva
  assert_equal "attiva", @account.classi.find_by(anno_corso: "1", sezione: "A").stato
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /archivia_classi_orfane/`
Expected: FAIL — orfana ancora `attiva`.

**Step 3: Write minimal implementation**

```ruby
def archivia_classi_orfane
  return unless source.stato == "attiva"  # lo storico 202526 non si archivia

  s = source
  c = s.col
  sql = <<~SQL
    UPDATE classi cl SET stato = 'archiviata', updated_at = now()
    FROM scuole sc
    WHERE cl.scuola_id = sc.id
      AND sc.account_id = :account_id AND sc.provincia = :provincia
      AND cl.anno_scolastico = :anno
      AND cl.stato = 'attiva'
      AND NOT EXISTS (
        SELECT 1 FROM (
          SELECT DISTINCT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
                 #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione
          FROM #{s.table}
        ) src
        WHERE src.codicescuola = cl.codice_ministeriale_origine
          AND src.annocorso IS NOT DISTINCT FROM cl.anno_corso
          AND src.sezioneanno IS NOT DISTINCT FROM cl.sezione
          AND src.combinazione IS NOT DISTINCT FROM cl.combinazione
      )
  SQL
  exec_sql(sql)
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /archivia_classi_orfane/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): archivia classi orfane (anno corrente)"
```

---

## Task 4: Upsert adozioni (ON CONFLICT DO NOTHING)

**Files:**
- Modify: `app/services/adozioni/reconciler.rb` (`upsert_adozioni`)
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "upsert_adozioni crea snapshot con anno_scolastico+codicescuola, idempotente" do
  seed_new_adozioni([
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", titolo: "Libro Uno", editore: "Giunti", prezzo: "12,50" },
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "222", daacquist: "No", titolo: "Libro Due", editore: "Giunti", prezzo: "9,90" }
  ])
  r = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627")
  r.send(:upsert_classi)

  assert_difference -> { Adozione.where(account: @account, anno_scolastico: "202627").count }, 2 do
    r.send(:upsert_adozioni)
  end
  a = Adozione.find_by(account: @account, codice_isbn: "111", anno_scolastico: "202627")
  assert_equal "BOEE00001A", a.codicescuola
  assert_equal true, a.da_acquistare
  assert_equal 1250, a.prezzo_cents

  assert_no_difference -> { Adozione.where(account: @account, anno_scolastico: "202627").count } do
    r.send(:upsert_adozioni)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /upsert_adozioni/`
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
       (COALESCE(NULLIF(replace(src.prezzo, ',', '.'), ''), '0')::float * 100)::int,
       (#{daacquist_bool('src.nuovaadoz', s)}),
       (#{s.daacquist_sql.gsub(/\b(daacquist|"DAACQUIST")\b/, 'src.\1')}),
       (#{daacquist_bool('src.consigliato', s)}),
       now(), now()
    FROM (
      SELECT #{c[:codicescuola]} AS codicescuola, #{c[:annocorso]} AS annocorso,
             #{c[:sezioneanno]} AS sezioneanno, #{c[:combinazione]} AS combinazione,
             #{c[:codiceisbn]} AS codiceisbn, #{c[:titolo]} AS titolo, #{c[:editore]} AS editore,
             #{c[:autori]} AS autori, #{c[:disciplina]} AS disciplina, #{c[:prezzo]} AS prezzo,
             #{c[:nuovaadoz]} AS nuovaadoz, #{c[:consigliato]} AS consigliato,
             #{daacquist_expr(s)} AS daacquist
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

> **Semplifica in implementazione:** l'interpolazione booleana sopra è fragile.
> Preferire due espressioni esplicite per anno invece del `gsub`:
> - `da_acquistare`: NEW → `src.daacquist ILIKE 'S%'`, IMPORT → `src.daacquist = 'Si'`
> - `nuova_adozione`/`consigliato`: `src.nuovaadoz = 'Si'` / `ILIKE 'S%'` per anno.
> Aggiungere al `Source` tre lambda/stringhe `bool_daacquist`, `bool_nuovaadoz`,
> `bool_consigliato` che lavorano sull'alias `src`. Rimuovere `daacquist_bool`/
> `daacquist_expr` se non servono. Il test resta la specifica: `da_acquistare=true`
> per `"Si"`/`ILIKE 'S%'`.

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /upsert_adozioni/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): upsert adozioni snapshot idempotente"
```

---

## Task 5: Cancella adozioni orfane (per anno)

**Files:**
- Modify: `app/services/adozioni/reconciler.rb` (`cancella_adozioni_orfane`)
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "cancella_adozioni_orfane rimuove le adozioni dell'anno non piu in sorgente" do
  seed_new_adozioni([
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", prezzo: "10,00" }
  ])
  r = Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627")
  r.send(:upsert_classi); r.send(:upsert_adozioni)
  classe = @account.classi.find_by(anno_corso: "1", sezione: "A")
  # adozione orfana (isbn non in sorgente)
  orfana = Adozione.create!(account: @account, classe: classe, codice_isbn: "999",
    anno_scolastico: "202627", codicescuola: "BOEE00001A", da_acquistare: true)

  assert_difference -> { Adozione.where(account: @account, anno_scolastico: "202627").count }, -1 do
    r.send(:cancella_adozioni_orfane)
  end
  assert_nil Adozione.find_by(id: orfana.id)
  assert Adozione.exists?(account: @account, codice_isbn: "111", anno_scolastico: "202627")
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /cancella_adozioni_orfane/`
Expected: FAIL — nessuna riga cancellata.

**Step 3: Write minimal implementation**

```ruby
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
        SELECT 1 FROM #{s.table} src
        WHERE #{c[:codicescuola]} = a.codicescuola
          AND #{c[:annocorso]}   IS NOT DISTINCT FROM a.anno_corso
          AND #{c[:codiceisbn]}  = a.codice_isbn
      )
  SQL
  exec_sql(sql)
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /cancella_adozioni_orfane/`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): cancella adozioni orfane per anno"
```

---

## Task 6: Ricalcola counter + integrazione `call`

**Files:**
- Modify: `app/services/adozioni/reconciler.rb` (`ricalcola_counter`)
- Test: `test/services/adozioni/reconciler_test.rb`

**Step 1: Write the failing test**

```ruby
test "call end-to-end aggiorna i counter della scuola" do
  seed_new_adozioni([
    { codicescuola: "BOEE00001A", annocorso: "1", sezioneanno: "A", combinazione: nil,
      codiceisbn: "111", daacquist: "Si", prezzo: "10,00" },
    { codicescuola: "BOEE00001A", annocorso: "2", sezioneanno: "B", combinazione: nil,
      codiceisbn: "222", daacquist: "Si", prezzo: "10,00" }
  ])
  Adozioni::Reconciler.new(account: @account, provincia: "BO", anno: "202627").call
  @scuola.reload
  assert_equal 2, @scuola.classi_count
  assert_equal 2, @scuola.adozioni_count
end
```

**Step 2: Run test to verify it fails**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb -n /end_to_end/`
Expected: FAIL — `classi_count` 0.

**Step 3: Write minimal implementation**

Estrai la logica counter esistente in un punto riusabile. Opzione DRY: sposta i 6
`UPDATE` di `UpdateScuolaMieAdozioniJob#update_counters` in
`Adozioni::CounterRecalc.new(account:, scuola_ids:).call` e chiama quella sia dal
job sia dal reconciler. Poi:

```ruby
def ricalcola_counter
  scuola_ids = account.scuole.where(provincia: provincia).pluck(:id)
  return if scuola_ids.empty?
  Adozioni::CounterRecalc.new(account: account, scuola_ids: scuola_ids).call
end
```

> Se preferisci non refattorizzare ora, duplica i 6 UPDATE scoped su `scuola_ids`
> (provincia) dentro `ricalcola_counter`. Ma l'estrazione è la scelta DRY corretta
> ed è a basso rischio (stesso SQL). Aggiornare `UpdateScuolaMieAdozioniJob` per
> delegare, mantenendo i suoi test verdi.

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/services/adozioni/reconciler_test.rb`
Expected: tutti PASS. Poi rilancia i test del job counter:
`docker exec prova-app-1 bin/rails test test/jobs/update_scuola_mie_adozioni_job_test.rb`
Expected: PASS (se esiste).

**Step 5: Commit**

```bash
git add -A && git commit -m "feat(reconciler): ricalcolo counter + estrazione CounterRecalc"
```

---

## Task 7: `ReconcileAdozioniJob` (wrapper per provincia)

**Files:**
- Create: `app/jobs/reconcile_adozioni_job.rb`
- Test: `test/jobs/reconcile_adozioni_job_test.rb`

**Step 1: Write the failing test**

```ruby
# test/jobs/reconcile_adozioni_job_test.rb
require "test_helper"

class ReconcileAdozioniJobTest < ActiveJob::TestCase
  test "usa la coda bulk e invoca il reconciler" do
    account = Account.create!(name: "Ed")
    assert_equal "bulk", ReconcileAdozioniJob.new.queue_name

    called = {}
    Adozioni::Reconciler.stub(:new, ->(**kw) { called.merge!(kw); Struct.new(:x).new.tap { |o| def o.call; end } }) do
      ReconcileAdozioniJob.perform_now(account, provincia: "BO", anno: "202627")
    end
    assert_equal "BO", called[:provincia]
    assert_equal "202627", called[:anno]
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
  queue_as :bulk

  def perform(account, provincia:, anno:)
    Current.account = account
    Adozioni::Reconciler.new(account: account, provincia: provincia, anno: anno).call
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

## Task 8: `ReconcileAccountJob` (orchestratore fan-out)

**Files:**
- Create: `app/jobs/reconcile_account_job.rb`
- Test: `test/jobs/reconcile_account_job_test.rb`

**Step 1: Write the failing test**

```ruby
# test/jobs/reconcile_account_job_test.rb
require "test_helper"

class ReconcileAccountJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "fa fan-out per provincia distinta × entrambi gli anni" do
    account = Account.create!(name: "Ed")
    Scuola.create!(account: account, codice_ministeriale: "BOEE1", provincia: "BO", grado: "E")
    Scuola.create!(account: account, codice_ministeriale: "MIEE1", provincia: "MI", grado: "E")

    assert_enqueued_jobs 4, only: ReconcileAdozioniJob do
      ReconcileAccountJob.perform_now(account)
    end
  end
end
```

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
    province = account.scuole.where.not(provincia: [nil, ""]).distinct.pluck(:provincia)
    province.each do |prov|
      ANNI.each { |anno| ReconcileAdozioniJob.perform_later(account, provincia: prov, anno: anno) }
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `docker exec prova-app-1 bin/rails test test/jobs/reconcile_account_job_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: ReconcileAccountJob orchestratore per provincia × anno"
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
      Adozioni::Reconciler.new(account: account, provincia: prov, anno: anno).call
      puts "Reconcile #{account.name} #{prov} #{anno}: OK"
    else
      ReconcileAccountJob.perform_later(account)
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
before = { classi: acc.classi.attive.joins(:scuola).where(scuole: {provincia: prov}).count }
Adozioni::Reconciler.new(account: acc, provincia: prov, anno: "202627").call
after = { classi: acc.classi.attive.joins(:scuola).where(scuole: {provincia: prov}).count }
puts({before:, after:}.inspect)
'
```

**Step 2:** Rilancia (idempotenza): i conteggi non cambiano.

**Step 3:** `ANALYZE` dopo il run massivo (NON `VACUUM FULL` — shm 64MB):
```bash
docker exec prova-app-1 bin/rails runner 'ActiveRecord::Base.connection.execute("ANALYZE classi; ANALYZE adozioni;")'
```

---

## Produzione — checklist rollout

1. Deploy del codice (job/service/rake).
2. Su una provincia pilota: `reconcile:adozioni ACCOUNT_ID=<bacherini> PROVINCIA=BO ANNO=202627`.
3. Verifica conteggi + idempotenza (ri-lancio).
4. Fan-out completo: `reconcile:adozioni ACCOUNT_ID=<bacherini>` (accoda per tutte
   le province × 2 anni sulla coda `bulk`).
5. Monitor coda `bulk` + temperatura (decine di job, non 16k).
6. `ANALYZE classi; ANALYZE adozioni;`.
7. **Dopo la validazione**: smettere di usare `PromuoviScuolePromuovibiliJob` per
   l'editore (la sostituzione UI è nella Sezione 4 del design).

## Cosa NON è in questo piano
- Anagrafe scuole (upsert `scuole`): resta all'import zone esistente.
- Fork admin/agente e dashboard analytics (Sezione 4).
- Assegnazione agenti (Sezione 3).
- Rimozione di `PromuoviScuolePromuovibiliJob` (dopo validazione, in Sezione 4).
