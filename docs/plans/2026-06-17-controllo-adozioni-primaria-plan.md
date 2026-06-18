# Controllo adozioni scuola primaria — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Materializzare, dopo ogni import MIUR, le anomalie delle adozioni della scuola primaria (EE) in una tabella, ed esporle in una pagina UI navigabile classifica → scuola → classe.

**Architecture:** Un rebuild set-based (SQL `INSERT … SELECT`) costruisce una tabella di staging `controllo_anomalie_stg` con 6 tipi di anomalia, poi la scambia atomicamente con `controllo_anomalie` (pattern blue-green identico a `import:new_adozioni`). Il rebuild è agganciato a fine import. Un controller read-only legge la tabella e mostra classifica/scuola/classe. La logica di dominio (requisiti obbligatori per classe, con OR sussidiario unico/coppia e religione/alternativa) vive in una costante Ruby, non in tabella.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest + fixtures, Turbo/Hotwire, CSS Fizzy (Propshaft), tutto via Docker (`docker exec prova-app-1 …`).

**Riferimenti:**
- Design: `docs/plans/2026-06-17-controllo-adozioni-primaria-design.md`
- Pattern blue-green: `lib/tasks/import.rake` (task `:new_adozioni`, righe ~410-560)
- Hook import: `app/services/miur/adozioni_scraper.rb:203-206`, `lib/tasks/scrape_libri.rake:175-178`
- Controller read-only di riferimento: `app/controllers/adozioni_analytics_controller.rb`
- Skill di stile: @superpowers-ruby:37signals-style, @superpowers-ruby:minitest (test), @frontend-design:frontend-design (UI, sempre con pattern Fizzy)

**Fatti di dominio chiave (verificati sul DB dev):**
- `new_adozioni.anno_scolastico` è `NULL` → nessun filtro anno su new_adozioni; universo = `tipogradoscuola = 'EE'` (~469k righe).
- `new_scuole.anno_scolastico = "202526"`, `prezzi_ministeriali.anno_scolastico = "2025/2026"`.
- Join `new_adozioni → new_scuole` SOLO per codice: `codicescuola = codice_scuola`.
- Join `new_adozioni → prezzi_ministeriali` su `classe = annocorso`, `disciplina`, anno = `PrezzoMinisteriale.anno_corrente`.
- Prezzo: stringa `"12,34"` → `round(replace(prezzo, ',', '.')::numeric * 100)::int`, con guardia `replace(prezzo, ',', '.') ~ '^\d+(\.\d+)?$'`.
- Alternativa religione: disciplina `ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94` (anche con spazio finale).

**Convenzioni di esecuzione:**
- Ogni comando di test gira nel container: `docker exec prova-app-1 bin/rails test <path>`.
- TDD: prima il test che fallisce, poi il minimo per farlo passare.
- Commit frequenti, un commit per task completato. **Non** committare senza che il task sia verde.
- Messaggi commit in formato Conventional Commits (vedi @superpowers-ruby:ruby-commit-message).

---

### Task 1: Migrazione tabella `controllo_anomalie`

**Files:**
- Create: `db/migrate/20260617000001_create_controllo_anomalie.rb`
- Modify (auto): `db/schema.rb`

**Step 1: Scrivi la migrazione**

```ruby
class CreateControlloAnomalie < ActiveRecord::Migration[8.1]
  def change
    create_table :controllo_anomalie, id: :uuid do |t|
      t.string  :anno_scolastico
      t.string  :codicescuola, null: false
      t.string  :annocorso
      t.string  :sezioneanno
      t.string  :combinazione
      t.string  :regione
      t.string  :provincia
      t.string  :comune
      t.string  :denominazione
      t.string  :tipo, null: false
      t.string  :disciplina
      t.string  :codiceisbn
      t.string  :titolo
      t.string  :editore
      t.integer :prezzo_cents
      t.integer :prezzo_atteso_cents
      t.integer :delta_cents
      t.jsonb   :dettaglio, null: false, default: {}
      t.timestamps
    end

    add_index :controllo_anomalie, [:codicescuola]
    add_index :controllo_anomalie, [:anno_scolastico, :codicescuola]
    add_index :controllo_anomalie, [:tipo]
    add_index :controllo_anomalie, [:provincia]
  end
end
```

**Step 2: Esegui la migrazione**

Run: `docker exec prova-app-1 bin/rails db:migrate`
Expected: crea `controllo_anomalie`, aggiorna `db/schema.rb`.

**Step 3: Prepara il DB di test**

Run: `docker exec prova-app-1 bin/rails db:test:prepare`
Expected: nessun errore.

**Step 4: Commit**

```bash
git add db/migrate/20260617000001_create_controllo_anomalie.rb db/schema.rb
git commit -m "feat(controllo): tabella controllo_anomalie"
```

---

### Task 2: Modello `ControlloAnomalia` + scopi

**Files:**
- Create: `app/models/controllo_anomalia.rb`
- Test: `test/models/controllo_anomalia_test.rb`

**Step 1: Scrivi il test che fallisce**

```ruby
require "test_helper"

class ControlloAnomaliaTest < ActiveSupport::TestCase
  test "TIPI elenca i sei tipi di controllo" do
    assert_equal %w[prezzo_isbn prezzo_disciplina disciplina_mancante doppione tetto_superato scuola_mancante].sort,
                 ControlloAnomalia::TIPI.sort
  end

  test "valida tipo incluso in TIPI" do
    a = ControlloAnomalia.new(codicescuola: "ABC", tipo: "non_esiste")
    assert_not a.valid?
    assert_includes a.errors[:tipo], "non incluso nell'elenco"
  end

  test "scope per_tipo filtra" do
    ControlloAnomalia.create!(codicescuola: "AA", tipo: "doppione")
    ControlloAnomalia.create!(codicescuola: "BB", tipo: "prezzo_isbn")
    assert_equal ["AA"], ControlloAnomalia.per_tipo("doppione").pluck(:codicescuola)
  end

  test "classifica raggruppa per scuola con conteggio decrescente" do
    3.times { ControlloAnomalia.create!(codicescuola: "TANTE", tipo: "doppione") }
    ControlloAnomalia.create!(codicescuola: "POCHE", tipo: "doppione")
    righe = ControlloAnomalia.classifica.to_a
    assert_equal "TANTE", righe.first.codicescuola
    assert_equal 3, righe.first.n_anomalie.to_i
  end
end
```

**Step 2: Esegui il test (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_anomalia_test.rb`
Expected: FAIL (uninitialized constant ControlloAnomalia).

**Step 3: Implementa il modello**

```ruby
class ControlloAnomalia < ApplicationRecord
  self.table_name = "controllo_anomalie"

  TIPI = %w[
    prezzo_isbn prezzo_disciplina disciplina_mancante doppione tetto_superato scuola_mancante
  ].freeze

  validates :codicescuola, presence: true
  validates :tipo, presence: true, inclusion: { in: TIPI, message: "non incluso nell'elenco" }

  scope :per_anno,    ->(anno) { where(anno_scolastico: anno) }
  scope :per_tipo,    ->(tipo) { where(tipo: tipo) }
  scope :per_scuola,  ->(cod)  { where(codicescuola: cod) }
  scope :per_classe,  ->(cod, annocorso, sezioneanno, combinazione) {
    where(codicescuola: cod, annocorso: annocorso, sezioneanno: sezioneanno, combinazione: combinazione)
  }

  # Classifica scuole per numero di anomalie (decrescente)
  scope :classifica, -> {
    select("codicescuola, MAX(denominazione) AS denominazione, MAX(provincia) AS provincia, " \
           "MAX(comune) AS comune, COUNT(*) AS n_anomalie")
      .group(:codicescuola)
      .order(Arel.sql("COUNT(*) DESC"))
  }
end
```

**Step 4: Esegui il test (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_anomalia_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_anomalia.rb test/models/controllo_anomalia_test.rb
git commit -m "feat(controllo): modello ControlloAnomalia con scopi e classifica"
```

---

### Task 3: Configurazione requisiti di dominio

Incapsula i requisiti obbligatori per classe (con OR sussidiario unico/coppia, religione/alt) in una costante + helper. È pura logica Ruby, testabile senza DB.

**Files:**
- Create: `app/models/controllo_adozioni/requisiti.rb`
- Test: `test/models/controllo_adozioni/requisiti_test.rb`

**Step 1: Scrivi il test che fallisce**

```ruby
require "test_helper"

class ControlloAdozioni::RequisitiTest < ActiveSupport::TestCase
  R = ControlloAdozioni::Requisiti

  test "la 2a non richiede religione" do
    chiavi = R.per_classe("2").map(&:chiave)
    assert_includes chiavi, :sussidiario_1biennio
    assert_includes chiavi, :inglese
    assert_not_includes chiavi, :religione_alt
  end

  test "la 4a richiede religione e il sussidiario discipline" do
    chiavi = R.per_classe("4").map(&:chiave)
    assert_includes chiavi, :religione_alt
    assert_includes chiavi, :sussidiario_discipline
  end

  test "religione_alt e' soddisfatto da RELIGIONE o ADOZIONE ALTERNATIVA" do
    req = R.per_classe("1").find { |r| r.chiave == :religione_alt }
    assert req.soddisfatto?(["RELIGIONE CATTOLICA"])
    assert req.soddisfatto?(["ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94"])
    assert_not req.soddisfatto?(["LINGUA INGLESE"])
  end

  test "sussidiario_discipline soddisfatto da unico OPPURE coppia ambiti" do
    req = R.per_classe("4").find { |r| r.chiave == :sussidiario_discipline }
    assert req.soddisfatto?(["SUSSIDIARIO DELLE DISCIPLINE"]), "unico"
    assert req.soddisfatto?([
      "SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)",
      "SUSSIDIARIO DELLE DISCIPLINE (AMBITO SCIENTIFICO)"
    ]), "coppia"
    assert_not req.soddisfatto?(["SUSSIDIARIO DELLE DISCIPLINE (AMBITO ANTROPOLOGICO)"]), "solo antropologico = NON soddisfatto"
  end
end
```

**Step 2: Esegui il test (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/requisiti_test.rb`
Expected: FAIL (uninitialized constant).

**Step 3: Implementa la configurazione**

```ruby
module ControlloAdozioni
  module Requisiti
    # Un requisito è soddisfatto se le discipline presenti soddisfano la sua regola.
    Requisito = Struct.new(:chiave, :regola, keyword_init: true) do
      # discipline_presenti: array di stringhe disciplina (UPCASE) dei libri daacquist della classe
      def soddisfatto?(discipline_presenti)
        regola.call(discipline_presenti.map { |d| d.to_s.strip.upcase })
      end
    end

    def self.match?(discipline, *patterns)
      discipline.any? { |d| patterns.any? { |p| d.include?(p) } }
    end

    INGLESE = Requisito.new(chiave: :inglese,
      regola: ->(d) { match?(d, "LINGUA INGLESE") })

    RELIGIONE_ALT = Requisito.new(chiave: :religione_alt,
      regola: ->(d) { match?(d, "RELIGIONE", "ADOZIONE ALTERNATIVA") })

    LIBRO_PRIMA = Requisito.new(chiave: :libro_prima_classe,
      regola: ->(d) { match?(d, "IL LIBRO DELLA PRIMA CLASSE") })

    SUSS_1BIENNIO = Requisito.new(chiave: :sussidiario_1biennio,
      regola: ->(d) { match?(d, "SUSSIDIARIO (1° BIENNIO)") })

    SUSS_LINGUAGGI = Requisito.new(chiave: :sussidiario_linguaggi,
      regola: ->(d) { match?(d, "SUSSIDIARIO DEI LINGUAGGI") })

    # Unico OPPURE (antropologico E scientifico)
    SUSS_DISCIPLINE = Requisito.new(chiave: :sussidiario_discipline,
      regola: ->(d) {
        unico = d.any? { |x| x.include?("SUSSIDIARIO DELLE DISCIPLINE") && !x.include?("AMBITO") }
        antro = match?(d, "AMBITO ANTROPOLOGICO")
        scien = match?(d, "AMBITO SCIENTIFICO")
        unico || (antro && scien)
      })

    PER_CLASSE = {
      "1" => [LIBRO_PRIMA, INGLESE, RELIGIONE_ALT],
      "2" => [SUSS_1BIENNIO, INGLESE],
      "3" => [SUSS_1BIENNIO, INGLESE],
      "4" => [SUSS_LINGUAGGI, SUSS_DISCIPLINE, INGLESE, RELIGIONE_ALT],
      "5" => [SUSS_LINGUAGGI, SUSS_DISCIPLINE, INGLESE],
    }.freeze

    def self.per_classe(annocorso)
      PER_CLASSE.fetch(annocorso.to_s, [])
    end
  end
end
```

**Step 4: Esegui il test (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/requisiti_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/requisiti.rb test/models/controllo_adozioni/requisiti_test.rb
git commit -m "feat(controllo): requisiti obbligatori per classe (OR sussidiario/religione)"
```

---

### Task 4: Fixtures di scenario (new_adozioni, new_scuole, prezzi_ministeriali)

Servono dati che producano **almeno una** anomalia di ciascun tipo. Useremo una scuola "buona" e una "problematica".

**Files:**
- Create: `test/fixtures/new_adozioni.yml`
- Create: `test/fixtures/new_scuole.yml`
- Create: `test/fixtures/prezzi_ministeriali.yml`

**Step 1: Scrivi `test/fixtures/prezzi_ministeriali.yml`**

```yaml
# Anno corrente di riferimento per i prezzi
pm_inglese_1:   { anno_scolastico: "2025/2026", classe: "1", disciplina: "LINGUA INGLESE", prezzo_cents: 1000 }
pm_libro_1:     { anno_scolastico: "2025/2026", classe: "1", disciplina: "IL LIBRO DELLA PRIMA CLASSE", prezzo_cents: 5000 }
pm_relig_1:     { anno_scolastico: "2025/2026", classe: "1", disciplina: "RELIGIONE", prezzo_cents: 1500 }
```

**Step 2: Scrivi `test/fixtures/new_scuole.yml`**

```yaml
buona:
  anno_scolastico: "202526"
  codice_scuola: "MIEE00001"
  denominazione: "Scuola Buona"
  comune: "Milano"
  provincia: "MI"
  regione: "LOMBARDIA"
  tipo_scuola: "SCUOLA PRIMARIA"

problematica:
  anno_scolastico: "202526"
  codice_scuola: "MIEE00002"
  denominazione: "Scuola Problematica"
  comune: "Milano"
  provincia: "MI"
  regione: "LOMBARDIA"
  tipo_scuola: "SCUOLA PRIMARIA"
# NB: la scuola "MIEE09999" usata nelle adozioni orfane NON esiste qui (genera scuola_mancante).
```

**Step 3: Scrivi `test/fixtures/new_adozioni.yml`**

```yaml
# --- Scuola buona, classe 1A: tutto regolare (nessuna anomalia) ---
buona_1a_libro:
  codicescuola: "MIEE00001"
  annocorso: "1"
  sezioneanno: "1A"
  combinazione: "X"
  codiceisbn: "ISBN-LIBRO1"
  disciplina: "IL LIBRO DELLA PRIMA CLASSE"
  titolo: "Libro Primo"
  editore: "ED. ALFA"
  prezzo: "50,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
buona_1a_inglese:
  codicescuola: "MIEE00001"
  annocorso: "1"
  sezioneanno: "1A"
  combinazione: "X"
  codiceisbn: "ISBN-ING1"
  disciplina: "LINGUA INGLESE"
  titolo: "English One"
  editore: "ED. BETA"
  prezzo: "10,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
buona_1a_relig:
  codicescuola: "MIEE00001"
  annocorso: "1"
  sezioneanno: "1A"
  combinazione: "X"
  codiceisbn: "ISBN-REL1"
  disciplina: "RELIGIONE"
  titolo: "Religione Uno"
  editore: "ED. GAMMA"
  prezzo: "15,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"

# --- Scuola problematica, classe 1B ---
# prezzo_isbn: stesso ISBN-ING1 ma prezzo diverso (9,00 vs modale 10,00)
prob_1b_inglese:
  codicescuola: "MIEE00002"
  annocorso: "1"
  sezioneanno: "1B"
  combinazione: "X"
  codiceisbn: "ISBN-ING1"
  disciplina: "LINGUA INGLESE"
  titolo: "English One"
  editore: "ED. BETA"
  prezzo: "9,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
# prezzo_disciplina: libro con prezzo (6000) != PM libro (5000)
prob_1b_libro:
  codicescuola: "MIEE00002"
  annocorso: "1"
  sezioneanno: "1B"
  combinazione: "X"
  codiceisbn: "ISBN-LIBRO-X"
  disciplina: "IL LIBRO DELLA PRIMA CLASSE"
  titolo: "Libro Caro"
  editore: "ED. ALFA"
  prezzo: "60,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
# doppione: due titoli distinti per la stessa disciplina (inglese) nella stessa classe
prob_1b_inglese_doppio:
  codicescuola: "MIEE00002"
  annocorso: "1"
  sezioneanno: "1B"
  combinazione: "X"
  codiceisbn: "ISBN-ING2"
  disciplina: "LINGUA INGLESE"
  titolo: "English Two"
  editore: "ED. DELTA"
  prezzo: "10,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
# disciplina_mancante: manca RELIGIONE_ALT in classe 1 (presenti solo inglese + libro)

# --- Adozione orfana: codicescuola assente da new_scuole -> scuola_mancante ---
orfana:
  codicescuola: "MIEE09999"
  annocorso: "1"
  sezioneanno: "1A"
  combinazione: "X"
  codiceisbn: "ISBN-ORF"
  disciplina: "LINGUA INGLESE"
  titolo: "Orfano"
  editore: "ED. ZETA"
  prezzo: "10,00"
  daacquist: "Sì"
  tipogradoscuola: "EE"
  volume: "1"
```

> Nota: per `tetto_superato` la classe 1B problematica supera il tetto perché libro 60,00 + inglese (9,00+10,00) > tetto atteso (libro 50 + inglese 10 + religione 15 = 75,00 → 75,00 vs spesa 79,00). Il test lo verificherà dopo l'implementazione del check 5.

**Step 4: Verifica che le fixtures carichino**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_anomalia_test.rb`
Expected: PASS (le fixtures vengono caricate; nessun errore di parsing YAML / colonne inesistenti).

**Step 5: Commit**

```bash
git add test/fixtures/new_adozioni.yml test/fixtures/new_scuole.yml test/fixtures/prezzi_ministeriali.yml
git commit -m "test(controllo): fixtures di scenario per le anomalie"
```

---

### Task 5: Scheletro del rebuild (staging + swap, nessun check)

Crea l'orchestratore che costruisce `controllo_anomalie_stg`, (per ora) non inserisce nulla, e fa lo swap atomico. Stabilisce il pattern blue-green prima di aggiungere i check.

**Files:**
- Create: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Scrivi il test che fallisce**

```ruby
require "test_helper"

class ControlloAdozioni::RebuildTest < ActiveSupport::TestCase
  # Il rebuild fa DDL (DROP/RENAME) → niente transazione di test.
  self.use_transactional_tests = false

  def teardown
    ControlloAnomalia.delete_all
  end

  test "run! svuota e ricostruisce la tabella senza errori" do
    ControlloAnomalia.create!(codicescuola: "VECCHIA", tipo: "doppione")
    ControlloAdozioni::Rebuild.run!
    # la riga preesistente è stata sostituita dallo swap
    assert_equal 0, ControlloAnomalia.where(codicescuola: "VECCHIA").count
  end
end
```

**Step 2: Esegui il test (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb`
Expected: FAIL (uninitialized constant Rebuild).

**Step 3: Implementa lo scheletro**

```ruby
module ControlloAdozioni
  class Rebuild
    STG = "controllo_anomalie_stg".freeze
    LIVE = "controllo_anomalie".freeze
    LOCK_KEY = 198_706_17 # arbitrario ma stabile: serializza rebuild concorrenti

    # Frammento SQL riusabile: prezzo stringa "12,34" -> cents int (NULL se non numerico)
    PREZZO_CENTS = "CASE WHEN replace(na.prezzo, ',', '.') ~ '^[0-9]+(\\.[0-9]+)?$' " \
                   "THEN round(replace(na.prezzo, ',', '.')::numeric * 100)::int END".freeze

    def self.run!(anno_prezzi: PrezzoMinisteriale.anno_corrente)
      new.run!(anno_prezzi: anno_prezzi)
    end

    def run!(anno_prezzi:)
      @anno_prezzi = anno_prezzi
      conn = ControlloAnomalia.connection
      return unless conn.select_value("SELECT pg_try_advisory_lock(#{LOCK_KEY})")

      begin
        conn.execute("DROP TABLE IF EXISTS #{STG}")
        conn.execute("CREATE TABLE #{STG} (LIKE #{LIVE} INCLUDING DEFAULTS INCLUDING CONSTRAINTS)")

        insert_checks(conn)

        conn.transaction do
          conn.execute("DROP TABLE #{LIVE}")
          conn.execute("ALTER TABLE #{STG} RENAME TO #{LIVE}")
        end
        rebuild_indexes(conn)
        conn.execute("ANALYZE #{LIVE}")
        ControlloAnomalia.reset_column_information
      ensure
        conn.execute("SELECT pg_advisory_unlock(#{LOCK_KEY})")
      end
    end

    private

    # Aggiunto check per check nei task successivi.
    def insert_checks(conn)
    end

    def rebuild_indexes(conn)
      conn.execute("CREATE INDEX IF NOT EXISTS index_controllo_anomalie_on_codicescuola ON #{LIVE} (codicescuola)")
      conn.execute("CREATE INDEX IF NOT EXISTS index_controllo_anomalie_on_anno_cod ON #{LIVE} (anno_scolastico, codicescuola)")
      conn.execute("CREATE INDEX IF NOT EXISTS index_controllo_anomalie_on_tipo ON #{LIVE} (tipo)")
      conn.execute("CREATE INDEX IF NOT EXISTS index_controllo_anomalie_on_provincia ON #{LIVE} (provincia)")
    end
  end
end
```

> Nota: `CREATE TABLE (LIKE … INCLUDING DEFAULTS)` mantiene il default `gen_random_uuid()` sull'id, quindi le `INSERT` dei check non devono specificare `id`. Gli indici si ricreano dopo lo swap (`IF NOT EXISTS` perché LIKE non copia gli indici).

**Step 4: Esegui il test (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): scheletro rebuild con staging e swap atomico"
```

---

### Task 6: Check `scuola_mancante` (anti-join)

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test che fallisce**

```ruby
  test "scuola_mancante per codicescuola assente da new_scuole" do
    ControlloAdozioni::Rebuild.run!
    orfane = ControlloAnomalia.per_tipo("scuola_mancante").pluck(:codicescuola)
    assert_includes orfane, "MIEE09999"
    assert_not_includes orfane, "MIEE00001"
  end
```

**Step 2: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb`
Expected: FAIL (nessuna riga scuola_mancante).

**Step 3: Implementa il check in `insert_checks`**

```ruby
    def insert_checks(conn)
      scuola_mancante(conn)
    end

    def scuola_mancante(conn)
      conn.execute(<<~SQL)
        INSERT INTO #{STG} (codicescuola, tipo, dettaglio)
        SELECT DISTINCT na.codicescuola, 'scuola_mancante', '{}'::jsonb
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND ns.id IS NULL
      SQL
    end
```

**Step 4: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): check scuola_mancante (adozioni orfane)"
```

---

### Task 7: Check `prezzo_disciplina`

Confronta il prezzo della riga col `PrezzoMinisteriale(annocorso, disciplina)` dell'anno corrente.

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test che fallisce**

```ruby
  test "prezzo_disciplina segnala il libro fuori prezzo (60 vs PM 50)" do
    ControlloAdozioni::Rebuild.run!
    a = ControlloAnomalia.per_tipo("prezzo_disciplina").find_by(codiceisbn: "ISBN-LIBRO-X")
    assert a, "attesa anomalia su ISBN-LIBRO-X"
    assert_equal 6000, a.prezzo_cents
    assert_equal 5000, a.prezzo_atteso_cents
    assert_equal 1000, a.delta_cents
    assert_equal "Scuola Problematica", a.denominazione # denorm da new_scuole
  end
```

**Step 2: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /prezzo_disciplina/`
Expected: FAIL.

**Step 3: Implementa**

Aggiungi `prezzo_disciplina(conn)` alla lista di `insert_checks` e il metodo:

```ruby
    def prezzo_disciplina(conn)
      anno = conn.quote(@anno_prezzi)
      conn.execute(<<~SQL)
        INSERT INTO #{STG} (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione,
          tipo, disciplina, codiceisbn, titolo, editore,
          prezzo_cents, prezzo_atteso_cents, delta_cents, dettaglio)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
          ns.regione, ns.provincia, ns.comune, ns.denominazione,
          'prezzo_disciplina', na.disciplina, na.codiceisbn, na.titolo, na.editore,
          (#{PREZZO_CENTS}) AS pc, pm.prezzo_cents, (#{PREZZO_CENTS}) - pm.prezzo_cents,
          '{}'::jsonb
        FROM new_adozioni na
        JOIN prezzi_ministeriali pm
          ON pm.anno_scolastico = #{anno}
         AND pm.classe = na.annocorso
         AND pm.disciplina = na.disciplina
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND (#{PREZZO_CENTS}) IS NOT NULL
          AND (#{PREZZO_CENTS}) <> pm.prezzo_cents
      SQL
    end
```

**Step 4: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /prezzo_disciplina/`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): check prezzo_disciplina vs PrezzoMinisteriale"
```

---

### Task 8: Check `prezzo_isbn` (modale nazionale per ISBN)

Lo stesso libro deve costare uguale ovunque. Calcola il prezzo modale per ISBN (dominanza alta) e segnala le righe difformi. Esclude religione/alternativa.

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test che fallisce**

Nelle fixtures `ISBN-ING1` compare a 10,00 (buona+modale di fatto) e a 9,00 (problematica). Con sole 2 righe la soglia `totale >= 50` non scatterebbe: per il test useremo una soglia iniettabile.

```ruby
  test "prezzo_isbn segnala la riga col prezzo difforme dal modale dell'ISBN" do
    # soglia bassa per il dataset di test
    ControlloAdozioni::Rebuild.run!(min_totale_isbn: 2)
    a = ControlloAnomalia.per_tipo("prezzo_isbn").find_by(codicescuola: "MIEE00002", codiceisbn: "ISBN-ING1")
    assert a, "attesa anomalia prezzo_isbn su ISBN-ING1 della scuola problematica"
    assert_equal 900, a.prezzo_cents
    assert_equal 1000, a.prezzo_atteso_cents
  end

  test "prezzo_isbn non segnala religione/alternativa" do
    ControlloAdozioni::Rebuild.run!(min_totale_isbn: 1)
    rel = ControlloAnomalia.per_tipo("prezzo_isbn").where("disciplina ILIKE 'RELIGIONE%'")
    assert_equal 0, rel.count
  end
```

**Step 2: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /prezzo_isbn/`
Expected: FAIL (run! non accetta min_totale_isbn).

**Step 3: Implementa**

Aggiorna la firma e aggiungi il metodo:

```ruby
    def self.run!(anno_prezzi: PrezzoMinisteriale.anno_corrente, min_totale_isbn: 50)
      new.run!(anno_prezzi: anno_prezzi, min_totale_isbn: min_totale_isbn)
    end

    def run!(anno_prezzi:, min_totale_isbn: 50)
      @anno_prezzi = anno_prezzi
      @min_totale_isbn = min_totale_isbn
      # ... resto invariato ...
    end
```

```ruby
    def prezzo_isbn(conn)
      conn.execute(<<~SQL)
        WITH ee AS (
          SELECT na.*, (#{PREZZO_CENTS}) AS prezzo_cents
          FROM new_adozioni na
          WHERE na.tipogradoscuola = 'EE' AND (#{PREZZO_CENTS}) IS NOT NULL
        ),
        ref AS (
          SELECT codiceisbn, prezzo_cents FROM (
            SELECT codiceisbn, prezzo_cents, count(*) AS freq,
                   sum(count(*)) OVER (PARTITION BY codiceisbn) AS totale,
                   row_number() OVER (PARTITION BY codiceisbn ORDER BY count(*) DESC) AS rn
            FROM ee GROUP BY codiceisbn, prezzo_cents
          ) s
          WHERE rn = 1 AND totale >= #{@min_totale_isbn.to_i} AND freq::float / totale > 0.9
        )
        INSERT INTO #{STG} (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione,
          tipo, disciplina, codiceisbn, titolo, editore,
          prezzo_cents, prezzo_atteso_cents, delta_cents, dettaglio)
        SELECT ee.codicescuola, ee.annocorso, ee.sezioneanno, ee.combinazione,
          ns.regione, ns.provincia, ns.comune, ns.denominazione,
          'prezzo_isbn', ee.disciplina, ee.codiceisbn, ee.titolo, ee.editore,
          ee.prezzo_cents, ref.prezzo_cents, ee.prezzo_cents - ref.prezzo_cents,
          '{}'::jsonb
        FROM ee
        JOIN ref USING (codiceisbn)
        LEFT JOIN new_scuole ns ON ns.codice_scuola = ee.codicescuola
        WHERE ee.prezzo_cents <> ref.prezzo_cents
          AND NOT (ee.disciplina ILIKE 'RELIGIONE%' OR ee.disciplina ILIKE 'ADOZIONE ALTERNATIVA%')
      SQL
    end
```

Aggiungi `prezzo_isbn(conn)` a `insert_checks`. Nota: dentro `ee` il frammento `PREZZO_CENTS` usa l'alias `na` → qui la sottoquery è `FROM new_adozioni na`, quindi va bene; nel `SELECT ... (#{PREZZO_CENTS})` di `ee` l'alias resta `na`. ✅

**Step 4: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /prezzo_isbn/`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): check prezzo_isbn (modale nazionale per ISBN)"
```

---

### Task 9: Check `doppione` (ignora volumi, esclude religione/alt)

Doppione = più di un (titolo, editore) distinto per la stessa `(classe, disciplina)`. I volumi dello stesso titolo NON contano (si raggruppa per titolo+editore, non per ISBN).

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test che fallisce**

```ruby
  test "doppione: due titoli inglese distinti nella stessa classe" do
    ControlloAdozioni::Rebuild.run!
    a = ControlloAnomalia.per_tipo("doppione").find_by(codicescuola: "MIEE00002", disciplina: "LINGUA INGLESE")
    assert a, "atteso doppione inglese in 1B"
    assert_equal 2, a.dettaglio["n_titoli"]
  end

  test "doppione: la scuola buona non ha doppioni" do
    ControlloAdozioni::Rebuild.run!
    assert_equal 0, ControlloAnomalia.per_tipo("doppione").where(codicescuola: "MIEE00001").count
  end
```

**Step 2: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /doppione/`
Expected: FAIL.

**Step 3: Implementa**

```ruby
    def doppione(conn)
      conn.execute(<<~SQL)
        INSERT INTO #{STG} (codicescuola, annocorso, sezioneanno, combinazione,
          regione, provincia, comune, denominazione, tipo, disciplina, dettaglio)
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
          max(ns.regione), max(ns.provincia), max(ns.comune), max(ns.denominazione),
          'doppione', na.disciplina,
          jsonb_build_object('n_titoli', count(DISTINCT coalesce(na.titolo,'') || '|' || coalesce(na.editore,'')))
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND NOT (na.disciplina ILIKE 'RELIGIONE%' OR na.disciplina ILIKE 'ADOZIONE ALTERNATIVA%')
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione, na.disciplina
        HAVING count(DISTINCT coalesce(na.titolo,'') || '|' || coalesce(na.editore,'')) > 1
      SQL
    end
```

Aggiungi `doppione(conn)` a `insert_checks`. Nota: `daacquist ILIKE 'S%'` cattura `"Sì"`/`"Si"`.

**Step 4: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /doppione/`
Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): check doppione (ignora volumi, esclude religione/alt)"
```

---

### Task 10: Check `disciplina_mancante` (modello a requisiti)

Per ogni classe EE, valuta i requisiti (Task 3) sulle discipline `daacquist` presenti; emette un'anomalia per ogni requisito non soddisfatto. Questo check è **ibrido**: la lista (classe → discipline presenti) si estrae in SQL, la valutazione OR si fa in Ruby usando `ControlloAdozioni::Requisiti`.

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test che fallisce**

```ruby
  test "disciplina_mancante: la 1B problematica non ha religione" do
    ControlloAdozioni::Rebuild.run!
    a = ControlloAnomalia.per_tipo("disciplina_mancante")
                         .find_by(codicescuola: "MIEE00002", annocorso: "1")
    assert a, "attesa disciplina_mancante in 1B"
    assert_equal "religione_alt", a.dettaglio["requisito"]
  end

  test "disciplina_mancante: la 1A buona non ha mancanti" do
    ControlloAdozioni::Rebuild.run!
    assert_equal 0, ControlloAnomalia.per_tipo("disciplina_mancante").where(codicescuola: "MIEE00001").count
  end
```

**Step 2: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /disciplina_mancante/`
Expected: FAIL.

**Step 3: Implementa (Ruby + batch insert)**

```ruby
    def disciplina_mancante(conn)
      sql = <<~SQL
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
               max(ns.regione) AS regione, max(ns.provincia) AS provincia,
               max(ns.comune) AS comune, max(ns.denominazione) AS denominazione,
               array_agg(DISTINCT na.disciplina) AS discipline
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND na.annocorso IN ('1','2','3','4','5')
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione
      SQL

      rows = conn.select_all(sql)
      buffer = []
      rows.each do |r|
        discipline = Array(r["discipline"])
        ControlloAdozioni::Requisiti.per_classe(r["annocorso"]).each do |req|
          next if req.soddisfatto?(discipline)
          buffer << {
            codicescuola: r["codicescuola"], annocorso: r["annocorso"],
            sezioneanno: r["sezioneanno"], combinazione: r["combinazione"],
            regione: r["regione"], provincia: r["provincia"], comune: r["comune"],
            denominazione: r["denominazione"], tipo: "disciplina_mancante",
            dettaglio: { requisito: req.chiave.to_s }
          }
        end
      end
      insert_buffer(conn, buffer)
    end

    # Inserisce un array di hash in STG (jsonb su dettaglio)
    def insert_buffer(conn, rows)
      return if rows.empty?
      cols = %i[codicescuola annocorso sezioneanno combinazione regione provincia comune denominazione tipo dettaglio]
      values = rows.map do |h|
        vals = cols.map do |c|
          v = h[c]
          c == :dettaglio ? "#{conn.quote(v.to_json)}::jsonb" : conn.quote(v)
        end
        "(#{vals.join(',')})"
      end
      conn.execute("INSERT INTO #{STG} (#{cols.join(',')}) VALUES #{values.join(',')}")
    end
```

> Nota PG: `array_agg(DISTINCT …)` arriva come stringa `"{LINGUA INGLESE,...}"`; il driver `pg` la converte in Array Ruby quando la colonna è tipata `text[]`. Se `select_all` restituisce la stringa grezza, usa `conn.select_all(sql).cast_values` non basta per gli array — in tal caso fai il parse con `PG::TextDecoder::Array.new.decode(r["discipline"])`. Verifica nel Step 4; se gli elementi non si splittano, applica il decoder.

Aggiungi `disciplina_mancante(conn)` a `insert_checks`.

**Step 4: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /disciplina_mancante/`
Expected: PASS. Se fallisce per il parsing dell'array, applica il decoder indicato nella nota e ri-esegui.

**Step 5: Commit**

```bash
git add app/models/controllo_adozioni/rebuild.rb test/models/controllo_adozioni/rebuild_test.rb
git commit -m "feat(controllo): check disciplina_mancante con modello a requisiti"
```

---

### Task 11: Check `tetto_superato`

Per ogni classe: spesa = somma prezzi dei libri `daacquist`; tetto = somma di un prezzo di riferimento `PrezzoMinisteriale` per ciascun requisito della classe (per `sussidiario_discipline`: prezzo dell'unico). Emette anomalia se spesa > tetto.

**Files:**
- Modify: `app/models/controllo_adozioni/rebuild.rb`
- Modify: `app/models/controllo_adozioni/requisiti.rb` (mappa requisito → disciplina di riferimento per il tetto)
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi alla config la disciplina di riferimento prezzo per requisito**

In `requisiti.rb`, aggiungi a `Requisito` il campo `prezzo_disciplina` (la disciplina PM da cui leggere il prezzo del tetto) e popolalo:

```ruby
    Requisito = Struct.new(:chiave, :regola, :prezzo_disciplina, keyword_init: true) do
      def soddisfatto?(discipline_presenti)
        regola.call(discipline_presenti.map { |d| d.to_s.strip.upcase })
      end
    end
    # ... e su ciascun requisito aggiungi prezzo_disciplina:
    # INGLESE        -> "LINGUA INGLESE"
    # RELIGIONE_ALT  -> "RELIGIONE"
    # LIBRO_PRIMA    -> "IL LIBRO DELLA PRIMA CLASSE"
    # SUSS_1BIENNIO  -> "SUSSIDIARIO (1° BIENNIO)"
    # SUSS_LINGUAGGI -> "SUSSIDIARIO DEI LINGUAGGI"
    # SUSS_DISCIPLINE-> "SUSSIDIARIO DELLE DISCIPLINE"
```

Aggiungi un helper:

```ruby
    # tetto in cents per una classe, dato un hash {disciplina => prezzo_cents} di PrezzoMinisteriale
    def self.tetto_cents(annocorso, prezzi_pm)
      per_classe(annocorso).sum { |r| prezzi_pm[r.prezzo_disciplina].to_i }
    end
```

Aggiorna il test dei requisiti (Task 3) per coprire `tetto_cents` se vuoi (facoltativo).

**Step 2: Aggiungi il test del rebuild che fallisce**

```ruby
  test "tetto_superato: la 1B problematica supera il tetto" do
    ControlloAdozioni::Rebuild.run!
    a = ControlloAnomalia.per_tipo("tetto_superato")
                         .find_by(codicescuola: "MIEE00002", annocorso: "1")
    assert a, "atteso tetto_superato in 1B"
    # spesa 1B = 60,00 + 9,00 + 10,00 = 79,00 ; tetto cl.1 = 50+10+15 = 75,00
    assert_equal 7900, a.prezzo_cents          # spesa
    assert_equal 7500, a.prezzo_atteso_cents   # tetto
  end
```

**Step 3: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /tetto/`
Expected: FAIL.

**Step 4: Implementa (Ruby, riusa il giro del check requisiti)**

```ruby
    def tetto_superato(conn)
      anno = conn.quote(@anno_prezzi)
      # prezzi PM per classe: { annocorso => { disciplina => prezzo_cents } }
      prezzi = Hash.new { |h, k| h[k] = {} }
      PrezzoMinisteriale.where(anno_scolastico: @anno_prezzi).each do |pm|
        prezzi[pm.classe][pm.disciplina] = pm.prezzo_cents
      end

      sql = <<~SQL
        SELECT na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione,
               max(ns.regione) AS regione, max(ns.provincia) AS provincia,
               max(ns.comune) AS comune, max(ns.denominazione) AS denominazione,
               sum(#{PREZZO_CENTS}) AS spesa
        FROM new_adozioni na
        LEFT JOIN new_scuole ns ON ns.codice_scuola = na.codicescuola
        WHERE na.tipogradoscuola = 'EE'
          AND coalesce(na.daacquist, '') ILIKE 'S%'
          AND na.annocorso IN ('1','2','3','4','5')
        GROUP BY na.codicescuola, na.annocorso, na.sezioneanno, na.combinazione
      SQL

      buffer = []
      conn.select_all(sql).each do |r|
        tetto = ControlloAdozioni::Requisiti.tetto_cents(r["annocorso"], prezzi[r["annocorso"]])
        next if tetto.zero?
        spesa = r["spesa"].to_i
        next unless spesa > tetto
        buffer << {
          codicescuola: r["codicescuola"], annocorso: r["annocorso"],
          sezioneanno: r["sezioneanno"], combinazione: r["combinazione"],
          regione: r["regione"], provincia: r["provincia"], comune: r["comune"],
          denominazione: r["denominazione"], tipo: "tetto_superato",
          prezzo_cents: spesa, prezzo_atteso_cents: tetto, delta_cents: spesa - tetto,
          dettaglio: {}
        }
      end
      insert_buffer_full(conn, buffer)
    end
```

Estendi `insert_buffer` per includere le colonne prezzo (o aggiungi `insert_buffer_full` con le colonne `prezzo_cents, prezzo_atteso_cents, delta_cents`). Suggerito: generalizza `insert_buffer` per accettare la lista colonne come parametro, evitando duplicazione (DRY).

Aggiungi `tetto_superato(conn)` a `insert_checks`.

**Step 5: Esegui (passa)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb -n /tetto/`
Expected: PASS.

**Step 6: Commit**

```bash
git add app/models/controllo_adozioni/ test/models/controllo_adozioni/
git commit -m "feat(controllo): check tetto_superato (somma prezzi attesi per requisito)"
```

---

### Task 12: Full rebuild integration test

Verifica che un singolo `run!` produca tutti i tipi e che la scuola buona resti pulita.

**Files:**
- Test: `test/models/controllo_adozioni/rebuild_test.rb`

**Step 1: Aggiungi il test**

```ruby
  test "rebuild completo: tutti i tipi presenti, scuola buona pulita" do
    ControlloAdozioni::Rebuild.run!(min_totale_isbn: 2)
    tipi = ControlloAnomalia.distinct.pluck(:tipo).sort
    assert_equal %w[disciplina_mancante doppione prezzo_disciplina prezzo_isbn scuola_mancante tetto_superato].sort, tipi
    assert_equal 0, ControlloAnomalia.where(codicescuola: "MIEE00001").count, "la scuola buona non deve avere anomalie"
  end
```

**Step 2: Esegui (atteso PASS)**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni/rebuild_test.rb`
Expected: PASS (tutti i test del file).

**Step 3: Commit**

```bash
git add test/models/controllo_adozioni/rebuild_test.rb
git commit -m "test(controllo): integrazione rebuild completo"
```

---

### Task 13: Rake task + hook nell'import

**Files:**
- Create: `lib/tasks/controllo_adozioni.rake`
- Modify: `app/services/miur/adozioni_scraper.rb:203-206`
- Modify: `lib/tasks/scrape_libri.rake:175-178`

**Step 1: Scrivi il rake task**

```ruby
namespace :controllo_adozioni do
  desc "Ricostruisce la tabella controllo_anomalie (scuola primaria EE)"
  task rebuild: :environment do
    Rails.logger.info "Inizio rebuild controllo_anomalie"
    ControlloAdozioni::Rebuild.run!
    Rails.logger.info "Rebuild controllo_anomalie completato: #{ControlloAnomalia.count} anomalie"
    puts "controllo_anomalie: #{ControlloAnomalia.count} righe"
  end
end
```

**Step 2: Aggancia dopo cambia_religione nello scraper**

In `app/services/miur/adozioni_scraper.rb`, dopo la riga `Rake::Task['import:cambia_religione'].invoke` (riga ~206), aggiungi:

```ruby
      Rake::Task['controllo_adozioni:rebuild'].reenable
      Rake::Task['controllo_adozioni:rebuild'].invoke
```

**Step 3: Aggancia anche in scrape_libri.rake**

In `lib/tasks/scrape_libri.rake`, dopo `Rake::Task['import:cambia_religione'].invoke` (riga ~177), aggiungi:

```ruby
      Rake::Task['controllo_adozioni:rebuild'].invoke
```

**Step 4: Verifica il task gira (manuale, su dev)**

Run: `docker exec prova-app-1 bin/rails controllo_adozioni:rebuild`
Expected: stampa "controllo_anomalie: N righe" senza errori (N > 0 sul dataset dev reale).

**Step 5: Commit**

```bash
git add lib/tasks/controllo_adozioni.rake app/services/miur/adozioni_scraper.rb lib/tasks/scrape_libri.rake
git commit -m "feat(controllo): rake rebuild agganciato a fine import MIUR"
```

---

### Task 14: Controller + rotte

Pagina classifica (`index`) e scuola (`show`). Default scuole dell'account; ricerca nazionale via `?q=`.

**Files:**
- Create: `app/controllers/controllo_adozioni_controller.rb`
- Modify: `config/routes.rb` (dentro lo scope account, vicino a `resource :adozioni_analytics`, riga ~376)
- Test: `test/controllers/controllo_adozioni_controller_test.rb`

**Step 1: Aggiungi la rotta**

In `config/routes.rb`, accanto a `resource :adozioni_analytics`:

```ruby
    resources :controllo_adozioni, only: %i[index show], param: :codicescuola
```

**Step 2: Scrivi il test del controller che fallisce**

```ruby
require "test_helper"

class ControlloAdozioniControllerTest < ActionDispatch::IntegrationTest
  # vedi test esistenti per il pattern di login/account; riusa l'helper di sessione del progetto
  setup do
    @anomalia = ControlloAnomalia.create!(codicescuola: "MIEE00002", tipo: "doppione",
      denominazione: "Scuola Problematica", provincia: "MI")
    sign_in_as_account # helper esistente nel progetto (adatta al nome reale)
  end

  test "index mostra la classifica" do
    get controllo_adozioni_index_url
    assert_response :success
    assert_match "Scuola Problematica", @response.body
  end

  test "show elenca le anomalie di una scuola" do
    get controllo_adozioni_url("MIEE00002")
    assert_response :success
    assert_match "doppione", @response.body
  end
end
```

> Adatta `sign_in_as_account` e gli url helper ai pattern reali (guarda `test/controllers/adozioni_*` o un controller test esistente che usa l'account namespace).

**Step 3: Esegui (fallisce)**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: FAIL.

**Step 4: Implementa il controller**

```ruby
class ControlloAdozioniController < ApplicationController
  before_action :authenticate_user!

  def index
    @q = params[:q].to_s.strip
    scope = ControlloAnomalia.classifica
    scope = if @q.present?
      scope.where("codicescuola ILIKE :q OR denominazione ILIKE :q OR comune ILIKE :q OR provincia ILIKE :q",
                  q: "%#{@q}%")
    else
      scope.where(codicescuola: codici_account)
    end
    scope = scope.where(provincia: params[:provincia]) if params[:provincia].present?
    @scuole = scope.limit(200)
  end

  def show
    @codicescuola = params[:codicescuola]
    @anomalie = ControlloAnomalia.per_scuola(@codicescuola)
    @per_tipo = @anomalie.group(:tipo).count
    # raggruppa per classe per la navigazione scuola -> classe -> anomalie
    @per_classe = @anomalie.where.not(annocorso: nil)
                           .group_by { |a| [a.annocorso, a.sezioneanno, a.combinazione] }
    @scuola_mancante = @anomalie.per_tipo("scuola_mancante").exists?
    @denominazione = @anomalie.where.not(denominazione: nil).first&.denominazione
  end

  private

  def codici_account
    scuole = Current.account.scuole.where.not(codice_ministeriale: [nil, ""])
    scuole = scuole.where(id: Current.membership.scuola_ids) unless Current.admin?
    scuole.pluck(:codice_ministeriale)
  end
end
```

**Step 5: Esegui (passa) — può fallire sulle viste mancanti**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: FAIL su "missing template" → si risolve nel Task 15.

**Step 6: Commit (rinviato)** — committa insieme alle viste nel Task 15.

---

### Task 15: Viste (stile Fizzy)

Usa @frontend-design:frontend-design con i pattern Fizzy (liste, filtri, badge). Riferimento: viste in `app/views/adozioni_analytics/` e classi CSS di Fizzy (`/home/paolotax/rails_2023/fizzy`).

**Files:**
- Create: `app/views/controllo_adozioni/index.html.erb`
- Create: `app/views/controllo_adozioni/show.html.erb`
- Create: `app/views/controllo_adozioni/_anomalia.html.erb`

**Step 1: `index.html.erb`** — barra ricerca `?q=` + filtro provincia + tabella classifica (scuola, provincia, n° anomalie come badge, link a `show`).

**Step 2: `show.html.erb`** — header scuola (+ avviso se `@scuola_mancante`), riepilogo `@per_tipo` come badge, poi per ogni classe (`@per_classe`) un blocco con le sue anomalie renderizzate da `_anomalia`.

**Step 3: `_anomalia.html.erb`** — riga anomalia: tipo (badge colore per gravità), disciplina/titolo, e per i prezzi `prezzo_cents` vs `prezzo_atteso_cents` con `delta_cents` (usa `number_to_currency(cents / 100.0)`).

> Mantieni le viste minime ma coerenti con Fizzy. Niente ViewComponent (deprecato). Usa le classi CSS esistenti (`input input--select` per le select — vedi memory feedback).

**Step 4: Esegui i test del controller (passano)**

Run: `docker exec prova-app-1 bin/rails test test/controllers/controllo_adozioni_controller_test.rb`
Expected: PASS.

**Step 5: Verifica visiva (manuale)**

Avvia/usa il dev server e apri `/<account>/controllo_adozioni`. Verifica classifica, ricerca, e drill-down su una scuola con anomalie reali (es. una `MIEE…`). Vedi skill `verify` / `run` se serve.

**Step 6: Commit**

```bash
git add app/controllers/controllo_adozioni_controller.rb config/routes.rb \
        app/views/controllo_adozioni/ test/controllers/controllo_adozioni_controller_test.rb
git commit -m "feat(controllo): UI classifica/scuola/classe delle anomalie adozioni"
```

---

### Task 16: Suite completa + verifica finale

**Step 1: Esegui i test del controllo**

Run: `docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/models/controllo_anomalia_test.rb test/controllers/controllo_adozioni_controller_test.rb`
Expected: tutto verde.

**Step 2: Esegui la suite completa (regressioni)**

Run: `docker exec prova-app-1 bin/rails test`
Expected: nessuna nuova rottura. (Le fixtures nuove `new_adozioni`/`new_scuole`/`prezzi_ministeriali` non devono interferire con altri test; se qualche test conta righe su quelle tabelle, valutare fixtures dedicate o `fixtures :all` già in uso.)

**Step 3: Verifica funzionale sul dato reale (dev)**

```bash
docker exec prova-app-1 bin/rails controllo_adozioni:rebuild
docker exec prova-app-1 bin/rails runner '
  puts ControlloAnomalia.group(:tipo).count.inspect
  puts "scuole con anomalie: #{ControlloAnomalia.distinct.count(:codicescuola)}"
'
```
Expected: conteggi plausibili per tutti i tipi; nessun errore.

**Step 4: (Solo su richiesta utente) annota la memory**

Se l'utente conferma, valuta una memory di progetto su `controllo_anomalie` (tabella derivata, rebuild agganciato all'import, requisiti di dominio). Vedi skill `superpowers-ruby:compound`.

---

## Note finali / decisioni rinviate (fuori scope v1)

- Notifiche/email automatiche delle anomalie.
- Soglie del modale ISBN (`min_totale_isbn`, dominanza 0.9) tarabili dopo aver visto i falsi positivi reali.
- Eventuale normalizzazione in due tabelle (riepilogo classe + dettaglio) se la tabella unica diventa scomoda.
- `anno_scolastico` su `controllo_anomalie` resta valorizzabile in futuro quando `new_adozioni.anno_scolastico` sarà popolato; oggi è lasciato `NULL` (eccetto record che derivano da PM).
