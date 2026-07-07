# Magazzino: giacenze, consegne parziali, acconti — Piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sostituire le 4 implementazioni concorrenti del calcolo giacenza con una tabella denormalizzata `giacenze` (pattern Saldo), introdurre consegne parziali (`consegna_righe`) e acconti (`pagamenti.importo_cents` + `tipo_pagamento_previsto`), unificando il segno in `Causale`.

**Architettura:** Il segno fisico vive solo in `Causale` (`segno` + `SEGNO_SQL`). `Giacenza` è una tabella per account+libro ricalcolata full-from-scratch (idempotente) da trigger nei concern e nei modelli riga. `Consegna` e `Pagamento` passano da `has_one` a `has_many`; gli stati (`consegnato?`, `pagato?`) diventano derivati dai residui. Saldo passa dai binari ai residui reali.

**Tech stack:** Rails 8.1, PostgreSQL (FILTER, LATERAL, ON CONFLICT), Minitest + fixtures. Design di riferimento: `docs/plans/2026-07-07-magazzino-giacenze-design.md`.

**Regole operative:**
- Tutti i comandi Rails girano nel container: `docker exec prova-app-1 bin/rails ...`
- Ogni task lascia l'app funzionante (i concern mantengono l'API `mark_consegnato`/`mark_pagato`/`consegnato?`/`pagato?`)
- Commit a fine task (l'approvazione di questo piano autorizza i commit per-task; regola CLAUDE.md rispettata)
- Dopo ogni migration: `docker exec prova-app-1 bundle exec annotaterb models`
- Niente worktree: si lavora sul branch corrente (feedback utente)

**Deviazione dichiarata dal design (motivata):** il design dice `consegnato?` = "residuo totale zero". Qui usiamo `consegnato?` = `consegne.any? && residuo zero`, simmetrico a `pagato?` (che il design definisce con `any?` proprio per i totali zero): senza `any?`, un documento appena creato senza righe risulterebbe "consegnato" da solo.

---

## Mappa dei file

| File | Azione | Responsabilità |
|---|---|---|
| `app/models/causale.rb` | Modifica | `segno`, `SEGNO_SQL`, enum `magazzino` |
| `db/migrate/..._create_magazzino_giacenze.rb` | Crea | Schema giacenze + consegna_righe + colonne + backfill consegne/pagamenti |
| `app/models/giacenza.rb` | Crea | Ricalcolo idempotente per libro + bulk per account |
| `app/models/consegna_riga.rb` | Crea | Riga di consegna (documento_riga + quantità) |
| `app/models/consegna.rb` | Modifica | has_many :consegna_righe, via validazione unique |
| `app/models/pagamento.rb` | Modifica | via validazione unique, validazione importo |
| `app/models/concerns/consegnabile.rb` | Riscrive | has_many, residui, consegna_parziale! |
| `app/models/concerns/pagabile.rb` | Riscrive | has_many, acconti, saturazione |
| `app/models/documento.rb` | Modifica | hook saturazione/auto-close, trigger giacenza |
| `app/models/documento_riga.rb` | Modifica | has_many :consegna_righe, trigger giacenza |
| `app/models/riga.rb` | Modifica | trigger giacenza |
| `app/models/saldo.rb` | Riscrive | ricalcolo sui residui reali |
| `app/models/libro.rb` | Modifica | has_one :giacenza (tabella), ricalcola_giacenza!, rimozione crosstab |
| `app/models/libro/movimenti.rb` | Modifica | scoping account, causale.segno, da_consegnare su residui |
| `app/models/libro/situazione.rb` | Crea | Query object export (sostituisce crosstab) |
| `lib/tasks/magazzino.rake` | Crea | Backfill/recovery giacenze |
| `app/controllers/documenti/consegna_controller.rb` | Modifica | consegna parziale opzionale, update ultima consegna |
| `app/controllers/documenti/pagamento_controller.rb` | Modifica | acconto opzionale, update ultimo pagamento |
| `app/controllers/libri_controller.rb` | Modifica | azione situazione, includes(:giacenza) |
| `app/views/documenti/container/_content.html.erb` | Modifica | select tipo_pagamento_previsto |
| `app/views/libri/situazione.xlsx.axlsx` | Crea | Export (sostituisce crosstab.xlsx.axlsx) |
| Sweep `:consegna`→`:consegne`, `:pagamento`→`:pagamenti` | Modifica | ~14 file elencati nel Task 3/5 |
| Cleanup finale | Elimina | view_giacenze, Views::Giacenza, LibroInfo, LibroSituazio, colonne legacy |

Test: `test/models/causale_test.rb` (nuovo), `test/models/giacenza_test.rb` (nuovo), `test/models/concerns/consegnabile_test.rb` (nuovo), `test/models/concerns/pagabile_test.rb` (nuovo), `test/models/libro/situazione_test.rb` (nuovo), `test/models/saldo_test.rb` (aggiornato), fixtures `righe.yml`/`documento_righe.yml` (nuove), `causali.yml` (corretta).

---

### Task 1: Causale — segno unico + enum magazzino

**Files:**
- Modify: `app/models/causale.rb`
- Modify: `test/fixtures/causali.yml`
- Create: `test/models/causale_test.rb`

Contesto: la colonna `causali.magazzino` (string) in DB contiene solo `"vendita"` e `"campionario"` (verificato in dev: 10 vendita, 7 campionario). Le fixture però hanno valori stantii (`"uscita"`, `"entrata"`) da correggere.

- [ ] **Step 1.1: Scrivi il test**

Crea `test/models/causale_test.rb`:

```ruby
require "test_helper"

class CausaleTest < ActiveSupport::TestCase
  fixtures :causali

  test "segno: entrata carica, uscita scarica" do
    assert_equal 1, causali(:ordine).segno          # movimento entrata
    assert_equal 1, causali(:nota_credito).segno    # TD04, entrata
    assert_equal(-1, causali(:vendita).segno)       # movimento uscita
    assert_equal(-1, causali(:fattura).segno)       # TD01, uscita
  end

  test "SEGNO_SQL coincide con #segno per ogni causale" do
    rows = Causale.pluck(:id, Arel.sql(Causale::SEGNO_SQL)).to_h
    Causale.find_each do |causale|
      assert_equal causale.segno, rows[causale.id], "segno divergente per #{causale.causale}"
    end
  end

  test "predicati magazzino" do
    assert causali(:fattura).magazzino_vendita?
    assert_not causali(:fattura).magazzino_campionario?
    assert causali(:scarico_saggi).magazzino_campionario?
    assert causali(:mancante).magazzino_campionario?
  end
end
```

- [ ] **Step 1.2: Correggi le fixture causali**

In `test/fixtures/causali.yml`: la fixture `vendita` ha `magazzino: "uscita"` e la fixture `ordine` ha `magazzino: "entrata"` — valori che non esistono più in DB. Cambia entrambe in `magazzino: "vendita"`. Aggiungi anche la causale di carico (serve dal Task 4 in poi):

```yaml
vendita:
  causale: "Vendita"
  magazzino: "vendita"
  tipo_movimento: 1
  movimento: 1

ordine:
  causale: "Ordine"
  magazzino: "vendita"
  tipo_movimento: 0
  movimento: 0

carico_fornitore:
  causale: "DDT Fornitore"
  magazzino: "vendita"
  tipo_movimento: 2
  movimento: 0
```

(Le altre fixture — `fattura`, `nota_credito`, `mancante`, `scarico_saggi`, `ordine_scuola` — restano invariate.)

- [ ] **Step 1.3: Esegui il test e verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/causale_test.rb`
Expected: FAIL — `undefined method 'segno'` / `uninitialized constant Causale::SEGNO_SQL`

- [ ] **Step 1.4: Implementa in Causale**

In `app/models/causale.rb`, subito dopo `enum :movimento, { entrata: 0, uscita: 1 }` aggiungi:

```ruby
  enum :magazzino, { vendita: "vendita", campionario: "campionario" }, prefix: :magazzino

  # Effetto fisico sul magazzino: entrata carica (+1), uscita scarica (-1).
  # Unica fonte del segno: Giacenza, Saldo e Movimenti derivano da qui.
  SEGNO_SQL = "CASE causali.movimento WHEN 0 THEN 1 ELSE -1 END".freeze

  def segno
    entrata? ? 1 : -1
  end
```

- [ ] **Step 1.5: Esegui i test e verifica che passino**

Run: `docker exec prova-app-1 bin/rails test test/models/causale_test.rb`
Expected: PASS (3 test)

Run anche l'intera suite modelli per escludere regressioni da enum:
`docker exec prova-app-1 bin/rails test test/models/`
Expected: PASS

- [ ] **Step 1.6: Commit**

```bash
git add app/models/causale.rb test/fixtures/causali.yml test/models/causale_test.rb
git commit -m "feat(causale): segno unico di magazzino + enum magazzino"
```

---

### Task 2: Migration — giacenze, consegna_righe, importo acconti, backfill

**Files:**
- Create: `db/migrate/<timestamp>_create_magazzino_giacenze.rb`

- [ ] **Step 2.1: Genera la migration**

Run: `docker exec prova-app-1 bin/rails generate migration CreateMagazzinoGiacenze`

- [ ] **Step 2.2: Scrivi la migration**

Contenuto completo (nota: `consegne.consegnabile_id` e `documento_righe.documento_id` sono entrambi uuid, nessun cast necessario; il backfill dà quantità piena a ogni consegna esistente e `importo_cents = totale_cents` a ogni pagamento esistente, come da design):

```ruby
class CreateMagazzinoGiacenze < ActiveRecord::Migration[8.1]
  def up
    create_table :giacenze, id: :uuid do |t|
      t.references :account, null: false, type: :uuid, index: true
      t.references :libro, null: false, index: true

      t.integer :disponibile, default: 0, null: false
      t.integer :campionario, default: 0, null: false
      t.integer :impegnato, default: 0, null: false
      t.integer :venduto_copie, default: 0, null: false
      t.bigint :venduto_cents, default: 0, null: false

      t.timestamps
    end
    add_index :giacenze, [:account_id, :libro_id], unique: true

    create_table :consegna_righe, id: :uuid do |t|
      t.references :consegna, null: false, type: :uuid, index: true
      t.references :documento_riga, null: false, index: true
      t.integer :quantita, null: false

      t.timestamps
    end

    add_column :pagamenti, :importo_cents, :bigint, null: false, default: 0
    add_column :documenti, :tipo_pagamento_previsto, :string

    # has_one -> has_many: cadono i vincoli di unicità
    remove_index :consegne, name: "index_consegne_on_consegnabile_type_and_consegnabile_id"
    remove_index :pagamenti, name: "index_pagamenti_on_pagabile_type_and_pagabile_id"

    # Backfill: ogni consegna esistente copre tutte le righe del documento a quantità piena
    execute <<~SQL
      INSERT INTO consegna_righe (id, consegna_id, documento_riga_id, quantita, created_at, updated_at)
      SELECT gen_random_uuid(), consegne.id, documento_righe.id, righe.quantita, consegne.created_at, consegne.created_at
      FROM consegne
      JOIN documento_righe ON documento_righe.documento_id = consegne.consegnabile_id
      JOIN righe ON righe.id = documento_righe.riga_id
      WHERE consegne.consegnabile_type = 'Documento'
    SQL

    # Backfill: ogni pagamento esistente salda l'intero documento
    execute <<~SQL
      UPDATE pagamenti
      SET importo_cents = COALESCE(documenti.totale_cents, 0)
      FROM documenti
      WHERE pagamenti.pagabile_type = 'Documento' AND pagamenti.pagabile_id = documenti.id
    SQL
  end

  def down
    add_index :pagamenti, [:pagabile_type, :pagabile_id], unique: true,
              name: "index_pagamenti_on_pagabile_type_and_pagabile_id"
    add_index :consegne, [:consegnabile_type, :consegnabile_id], unique: true,
              name: "index_consegne_on_consegnabile_type_and_consegnabile_id"
    remove_column :documenti, :tipo_pagamento_previsto
    remove_column :pagamenti, :importo_cents
    drop_table :consegna_righe
    drop_table :giacenze
  end
end
```

- [ ] **Step 2.3: Esegui la migration e annota**

Run: `docker exec prova-app-1 bin/rails db:migrate`
Expected: migrazione OK, nessun errore sui backfill

Run: `docker exec prova-app-1 bundle exec annotaterb models`

Verifica backfill in dev:
`docker exec prova-app-1 bin/rails runner 'puts "consegna_righe: #{ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM consegna_righe")}"; puts "pagamenti a zero: #{Pagamento.where(importo_cents: 0).count}"'`
Expected: consegna_righe > 0; pagamenti a zero = solo eventuali documenti a totale zero

- [ ] **Step 2.4: Esegui la suite**

Run: `docker exec prova-app-1 bin/rails test test/models/`
Expected: PASS (il codice usa ancora has_one, la validazione Ruby di unicità resta attiva: comportamento invariato)

- [ ] **Step 2.5: Commit**

```bash
git add db/migrate db/structure.sql app/models
git commit -m "feat(magazzino): schema giacenze, consegna_righe, acconti + backfill"
```

---

### Task 3: Consegne parziali — ConsegnaRiga + Consegnabile has_many

**Files:**
- Create: `app/models/consegna_riga.rb`
- Modify: `app/models/consegna.rb`
- Modify: `app/models/concerns/consegnabile.rb` (riscrittura)
- Modify: `app/models/documento.rb` (auto-close via hook)
- Modify: `app/models/documento_riga.rb` (has_many :consegna_righe)
- Modify: `app/models/saldo.rb:33` (patch interim `:consegna` → `:consegne`)
- Modify: `app/controllers/documenti/consegna_controller.rb`
- Modify (sweep `:consegna` → `:consegne`): vedi step 3.6
- Create: `test/models/concerns/consegnabile_test.rb`
- Create: `test/fixtures/righe.yml`, `test/fixtures/documento_righe.yml`

Nota inflection: `config/initializers/inflections.rb` ha già `inflect.irregular 'riga', 'righe'`, quindi `ConsegnaRiga` → tabella `consegna_righe` automaticamente.

- [ ] **Step 3.1: Crea le fixture righe e documento_righe**

Le fixture documenti hanno `totale_cents`/`totale_copie` ma nessuna riga: servono righe coerenti coi totali (prezzo 100,00 € = 10000 cents, sconto 0) sia per i test di Consegnabile sia per Saldo (Task 6).

Crea `test/fixtures/righe.yml`:

```yaml
riga_documento_fizzy:
  libro: libro_fizzy
  quantita: 10
  prezzo_cents: 10000
  sconto: 0.0

riga_fattura_uno:
  libro: libro_fizzy
  quantita: 20
  prezzo_cents: 10000
  sconto: 0.0

riga_fattura_due:
  libro: libro_fizzy
  quantita: 15
  prezzo_cents: 10000
  sconto: 0.0

riga_ordine_figlio:
  libro: libro_fizzy
  quantita: 8
  prezzo_cents: 10000
  sconto: 0.0

riga_nota_credito:
  libro: libro_fizzy
  quantita: 3
  prezzo_cents: 10000
  sconto: 0.0

riga_documento_acme:
  libro: libro_acme
  quantita: 5
  prezzo_cents: 10000
  sconto: 0.0
```

Crea `test/fixtures/documento_righe.yml`:

```yaml
dr_documento_fizzy:
  documento: documento_fizzy
  riga: riga_documento_fizzy
  posizione: 1

dr_fattura_uno:
  documento: fattura_uno
  riga: riga_fattura_uno
  posizione: 1

dr_fattura_due:
  documento: fattura_due
  riga: riga_fattura_due
  posizione: 1

dr_ordine_figlio:
  documento: ordine_figlio
  riga: riga_ordine_figlio
  posizione: 1

dr_nota_credito:
  documento: nota_credito_fizzy
  riga: riga_nota_credito
  posizione: 1

dr_documento_acme:
  documento: documento_acme
  riga: riga_documento_acme
  posizione: 1
```

- [ ] **Step 3.2: Scrivi il test del concern**

Crea `test/models/concerns/consegnabile_test.rb`:

```ruby
require "test_helper"

class ConsegnabileTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @documento = documenti(:fattura_uno) # 1 riga da 20 copie
    @documento_riga = documento_righe(:dr_fattura_uno)
  end

  teardown do
    Current.reset
  end

  test "mark_consegnato consegna tutti i residui in un colpo" do
    @documento.mark_consegnato

    assert @documento.consegnato?
    assert_not @documento.parzialmente_consegnato?
    assert_equal 1, @documento.consegne.count
    assert_equal 20, @documento.consegne.first.consegna_righe.sum(:quantita)
    assert_equal 0, @documento.copie_residue_da_consegnare
  end

  test "mark_consegnato è idempotente" do
    @documento.mark_consegnato
    assert_no_difference -> { Consegna.count } do
      @documento.mark_consegnato
    end
  end

  test "consegna_parziale! lascia il residuo e lo stato parziale" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })

    assert_not @documento.consegnato?
    assert @documento.parzialmente_consegnato?
    assert_equal 8, @documento.copie_residue_da_consegnare
    assert_equal({ @documento_riga.id => 8 }, @documento.residui_per_documento_riga)
  end

  test "due consegne parziali saturano il documento" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })
    @documento.consegna_parziale!({ @documento_riga.id => 8 })

    assert @documento.consegnato?
    assert_equal 2, @documento.consegne.count
  end

  test "consegna_parziale! oltre il residuo solleva ArgumentError" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 })

    assert_raises(ArgumentError) do
      @documento.consegna_parziale!({ @documento_riga.id => 9 })
    end
  end

  test "consegna_parziale! senza quantità positive solleva ArgumentError" do
    assert_raises(ArgumentError) do
      @documento.consegna_parziale!({ @documento_riga.id => 0 })
    end
  end

  test "unmark_consegnato distrugge una consegna specifica e i residui riaumentano" do
    prima = @documento.consegna_parziale!({ @documento_riga.id => 12 })
    @documento.consegna_parziale!({ @documento_riga.id => 8 })

    @documento.unmark_consegnato(prima)

    assert_not @documento.consegnato?
    assert_equal 12, @documento.copie_residue_da_consegnare
  end

  test "unmark_consegnato senza argomento toglie l'ultima consegna" do
    @documento.mark_consegnato
    @documento.unmark_consegnato

    assert_not @documento.consegnato?
    assert_equal 0, @documento.consegne.count
  end

  test "consegnato_il è la data dell'ultima consegna" do
    @documento.consegna_parziale!({ @documento_riga.id => 12 }, consegnato_il: 3.days.ago)
    @documento.consegna_parziale!({ @documento_riga.id => 8 }, consegnato_il: 1.day.ago)

    assert_in_delta 1.day.ago.to_f, @documento.consegnato_il.to_f, 5
  end

  test "documento senza consegne non è consegnato" do
    assert_not @documento.consegnato?
    assert_not @documento.parzialmente_consegnato?
    assert_nil @documento.consegnato_il
  end

  test "mark_consegnato su documento senza righe crea la consegna vuota" do
    doc = Documento.create!(account: accounts(:fizzy), user: users(:one),
                            causale: causali(:fattura), clientable: clienti(:cliente_fizzy),
                            numero_documento: 999, data_documento: Date.today)
    doc.mark_consegnato
    assert doc.consegnato?
  end
end
```

- [ ] **Step 3.3: Esegui il test e verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/concerns/consegnabile_test.rb`
Expected: FAIL — `undefined method 'consegne'` / `consegna_parziale!`

- [ ] **Step 3.4: Implementa i modelli**

Crea `app/models/consegna_riga.rb`:

```ruby
class ConsegnaRiga < ApplicationRecord
  belongs_to :consegna
  belongs_to :documento_riga

  validates :quantita, numericality: { only_integer: true, greater_than: 0 }
end
```

Riscrivi `app/models/consegna.rb` (rimuovi la validazione di unicità, aggiungi righe — conserva il commento schema annotate in testa):

```ruby
class Consegna < ApplicationRecord
  belongs_to :account, default: -> { consegnabile.account }
  belongs_to :consegnabile, polymorphic: true, touch: true
  belongs_to :user, optional: true, default: -> { Current.user }

  has_many :consegna_righe, dependent: :destroy

  def copie
    consegna_righe.sum(:quantita)
  end
end
```

In `app/models/documento_riga.rb`, dopo `has_one :bolla_visione_riga` aggiungi:

```ruby
  has_many :consegna_righe, dependent: :destroy
```

Riscrivi `app/models/concerns/consegnabile.rb`:

```ruby
module Consegnabile
  extend ActiveSupport::Concern

  included do
    has_many :consegne, as: :consegnabile, dependent: :destroy
  end

  # Fast path: un click consegna tutti i residui
  def mark_consegnato(user: Current.user, consegnato_il: nil)
    return if consegnato?

    transaction do
      consegna = consegne.create!(user: user, consegnato_il: consegnato_il || Time.current)
      residui_per_documento_riga.each do |documento_riga_id, quantita|
        consegna.consegna_righe.create!(documento_riga_id: documento_riga_id, quantita: quantita)
      end
    end
    dopo_variazione_consegne
  end

  # Consegna solo le quantità indicate: { documento_riga_id => quantita }
  def consegna_parziale!(quantita_per_documento_riga, user: Current.user, consegnato_il: nil)
    da_consegnare = quantita_per_documento_riga.to_h { |k, v| [k.to_s, v.to_i] }
                                               .select { |_, quantita| quantita.positive? }
    raise ArgumentError, "nessuna quantità da consegnare" if da_consegnare.empty?

    residui = residui_per_documento_riga.transform_keys(&:to_s)
    da_consegnare.each do |documento_riga_id, quantita|
      residuo = residui.fetch(documento_riga_id, 0)
      if quantita > residuo
        raise ArgumentError, "quantità #{quantita} oltre il residuo #{residuo} (documento_riga #{documento_riga_id})"
      end
    end

    consegna = nil
    transaction do
      consegna = consegne.create!(user: user, consegnato_il: consegnato_il || Time.current)
      da_consegnare.each do |documento_riga_id, quantita|
        consegna.consegna_righe.create!(documento_riga_id: documento_riga_id, quantita: quantita)
      end
    end
    dopo_variazione_consegne
    consegna
  end

  def unmark_consegnato(consegna = nil)
    (consegna || consegne.order(:consegnato_il).last)&.destroy
    dopo_variazione_consegne
  end

  def consegnato?
    consegne.any? && copie_residue_da_consegnare.zero?
  end

  def parzialmente_consegnato?
    consegne.any? && copie_residue_da_consegnare.positive?
  end

  def consegnato_il
    consegne.maximum(:consegnato_il)
  end

  def copie_residue_da_consegnare
    residui_per_documento_riga.values.sum
  end

  # { documento_riga_id => residuo }, solo righe con residuo positivo
  def residui_per_documento_riga
    @residui_per_documento_riga ||= begin
      consegnate = ConsegnaRiga.joins(:consegna)
        .where(consegne: { consegnabile_type: self.class.base_class.name, consegnabile_id: id })
        .group(:documento_riga_id)
        .sum(:quantita)

      documento_righe.joins(:riga).pluck(:id, Arel.sql("righe.quantita"))
        .each_with_object({}) do |(documento_riga_id, quantita), residui|
          residuo = quantita - consegnate.fetch(documento_riga_id, 0)
          residui[documento_riga_id] = residuo if residuo.positive?
        end
    end
  end

  private

  def dopo_variazione_consegne
    consegne.reset
    @residui_per_documento_riga = nil
    ricalcola_saldo_clientable
    auto_close_se_completo if respond_to?(:auto_close_se_completo)
  end

  def ricalcola_saldo_clientable
    clientable = try(:clientable)
    clientable.ricalcola_saldo! if clientable.respond_to?(:ricalcola_saldo!)
  end
end
```

- [ ] **Step 3.5: Adegua Documento all'hook auto-close**

In `app/models/documento.rb`:

1. Rimuovi la riga `after_save :auto_close_se_completo` (la saturazione ora chiama l'hook dal concern). Lascia per ora `after_save :propaga_pagamento_ai_figli, if: :just_marked_pagato?` (si sistema nel Task 5).
2. Sposta `auto_close_se_completo` da `private` a pubblico e semplificalo (niente più `previously_new_record?` — viene invocato solo alla variazione di consegne/pagamenti, quindi il save di una riga non richiude un documento riaperto):

```ruby
  # Chiamato da Consegnabile/Pagabile a ogni variazione di consegne/pagamenti
  def auto_close_se_completo
    close if pagato? && consegnato? && !closed?
  end
```

3. In `eredita_stato_da_origini` nessuna modifica (usa l'API dei concern).

- [ ] **Step 3.6: Sweep `:consegna` → `:consegne` nei reader**

Rinomina il simbolo di associazione nei punti che usano `includes/left_joins/joins/where.missing(:consegna)` (il significato "nessuna consegna" resta identico — dopo il backfill tutte le consegne esistenti sono complete):

- `app/models/saldo.rb:33` → `da_consegnare = documenti.left_joins(:consegne).where(consegne: { id: nil })`
- `app/controllers/documenti_controller.rb:39` (`includes(... :consegna ...)` → `:consegne`)
- `app/controllers/agenda_controller.rb:208,299,316` (`left_joins(:consegna, :pagamento)` → `left_joins(:consegne, :pagamento)`)
- `app/controllers/vendite_controller.rb:45` (`where.missing(:consegna)` → `where.missing(:consegne)`)
- `app/controllers/documenti/bulk_pagamenti_controller.rb:39,45`
- `app/controllers/documenti/bulk_derivazioni_controller.rb:10`
- `app/controllers/documenti/bulk_stati_controller.rb:7`
- `app/controllers/entries/bulk_gestione_controller.rb:9`
- `app/controllers/documenti/bulk_gestione_controller.rb:7`
- `app/models/entry.rb:147`
- `app/models/filters/documento_filter.rb:46,65,82,117`
- `app/tools/mcp_tools/vendite_per_libro.rb:83`
- `app/tools/mcp_tools/documenti_list.rb:56,64`
- `app/models/libro/movimenti.rb:12` → `merge(Documento.where.missing(:consegne))` (refactor completo nel Task 8; qui solo il rename per non rompere)

Poi verifica di non aver dimenticato nulla:

Run: `grep -rn "includes(:.*:consegna[^_e]\|left_joins(:consegna[^_e]\|missing(:consegna)\|joins(:consegna)" app/ lib/`
Expected: nessun risultato

- [ ] **Step 3.7: Adegua ConsegnaController**

In `app/controllers/documenti/consegna_controller.rb`:

`create` diventa (consegna parziale se arrivano le righe, altrimenti fast path):

```ruby
    # POST /documenti/:documento_id/consegna
    # params[:righe] opzionale: { documento_riga_id => quantita } per consegna parziale
    def create
      if params[:righe].present?
        @documento.consegna_parziale!(params[:righe].to_unsafe_h, consegnato_il: parsed_date(:consegnato_il))
      else
        @documento.mark_consegnato(consegnato_il: parsed_date(:consegnato_il))
      end

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json { render json: { ok: true, consegnato: @documento.consegnato?, consegnato_il: @documento.consegnato_il } }
      end
    end
```

`update` (riga 22): `@documento.consegna&.update!(...)` → `@documento.consegne.order(:consegnato_il).last&.update!(consegnato_il: parsed_date(:consegnato_il))` e nel json `@documento.consegna&.consegnato_il` → `@documento.consegnato_il`.

- [ ] **Step 3.8: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/concerns/consegnabile_test.rb`
Expected: PASS

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS (saldo_test verde: i binari da_consegnare/da_pagare funzionano come prima)

- [ ] **Step 3.9: Commit**

```bash
git add app/models app/controllers test/
git commit -m "feat(consegne): consegne parziali con consegna_righe, Consegna has_many"
```

---

### Task 4: Giacenza — modello, ricalcolo idempotente, backfill

**Files:**
- Create: `app/models/giacenza.rb`
- Modify: `app/models/libro.rb` (solo `ricalcola_giacenza!`, l'associazione si sposta nel Task 7)
- Create: `lib/tasks/magazzino.rake`
- Create: `test/models/giacenza_test.rb`

- [ ] **Step 4.1: Scrivi il test (il cuore del design)**

Crea `test/models/giacenza_test.rb`:

```ruby
require "test_helper"

class GiacenzaTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    Current.account = @account
    Current.user = @user

    # Libro dedicato: le fixture righe usano libro_fizzy e inquinerebbero i conteggi
    @libro = Libro.create!(account: @account, user: @user, titolo: "Libro magazzino",
                           codice_isbn: "TEST-GIAC-1", prezzo_in_cents: 10000,
                           categoria: categorie(:scolastica))
  end

  teardown do
    Current.reset
  end

  test "carico fornitore carica il disponibile" do
    crea_documento(causali(:carico_fornitore), quantita: 10)

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 0, giacenza.venduto_copie
    assert_equal 0, giacenza.campionario
  end

  test "vendita non consegnata impegna, non scarica" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    crea_documento(causali(:fattura), quantita: 4)

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
    assert_equal 4, giacenza.impegnato
    assert_equal 0, giacenza.venduto_copie
  end

  test "consegna parziale splitta impegnato e venduto" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 3 })

    giacenza = ricalcola
    assert_equal 7, giacenza.disponibile        # 10 - 3 consegnate
    assert_equal 1, giacenza.impegnato          # 4 - 3
    assert_equal 3, giacenza.venduto_copie
    assert_equal 3 * 10000, giacenza.venduto_cents
  end

  test "vendita consegnata scarica e vende" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.mark_consegnato

    giacenza = ricalcola
    assert_equal 6, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 4, giacenza.venduto_copie
    assert_equal 4 * 10000, giacenza.venduto_cents
  end

  test "TD04 consegnata rientra in giacenza e riduce il venduto" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    nota = crea_documento(causali(:nota_credito), quantita: 2)
    nota.mark_consegnato

    giacenza = ricalcola
    assert_equal 12, giacenza.disponibile       # rientro fisico
    assert_equal(-2, giacenza.venduto_copie)
    assert_equal(-2 * 10000, giacenza.venduto_cents)
  end

  test "lo sconto valorizza il venduto al prezzo scontato" do
    vendita = crea_documento(causali(:fattura), quantita: 2, sconto: 20.0)
    vendita.mark_consegnato

    giacenza = ricalcola
    assert_equal 2 * 8000, giacenza.venduto_cents   # 10000 - 20%
  end

  test "il campionario si muove senza gating di consegna" do
    crea_documento(causali(:scarico_saggi), quantita: 5)

    giacenza = ricalcola
    assert_equal(-5, giacenza.campionario)
    assert_equal 0, giacenza.disponibile
  end

  test "gli ordini (tipo_movimento ordine) non muovono nulla" do
    crea_documento(causali(:ordine), quantita: 7)

    giacenza = ricalcola
    assert_equal 0, giacenza.disponibile
    assert_equal 0, giacenza.impegnato
    assert_equal 0, giacenza.campionario
  end

  test "il documento figlio non conta (righe condivise col padre)" do
    padre = crea_documento(causali(:fattura), quantita: 4)
    figlio = Documento.create!(account: @account, user: @user, causale: causali(:vendita),
                               clientable: @cliente, numero_documento: prossimo_numero,
                               data_documento: Date.today, documento_padre: padre)
    figlio.documento_righe.create!(riga: padre.righe.first)

    giacenza = ricalcola
    assert_equal 4, giacenza.impegnato
  end

  test "i documenti di altri account sono esclusi" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    Documento.create!(account: accounts(:acme), user: users(:multi_account),
                      causale: causali(:carico_fornitore), clientable: clienti(:cliente_acme),
                      numero_documento: prossimo_numero, data_documento: Date.today)
      .documento_righe.create!(riga: Riga.create!(libro: @libro, quantita: 99, prezzo_cents: 10000))

    giacenza = ricalcola
    assert_equal 10, giacenza.disponibile
  end

  test "ricalcola_tutte! coincide col ricalcolo per libro" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.consegna_parziale!({ vendita.documento_righe.first.id => 3 })

    per_libro = ricalcola.attributes.slice("disponibile", "campionario", "impegnato", "venduto_copie", "venduto_cents")
    Giacenza.delete_all

    Giacenza.ricalcola_tutte!(@account)
    bulk = Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id)
      .attributes.slice("disponibile", "campionario", "impegnato", "venduto_copie", "venduto_cents")

    assert_equal per_libro, bulk
  end

  private

  def crea_documento(causale, quantita:, sconto: 0.0, clientable: @cliente)
    documento = Documento.create!(account: @account, user: @user, causale: causale,
                                  clientable: clientable, numero_documento: prossimo_numero,
                                  data_documento: Date.today)
    riga = Riga.create!(libro: @libro, quantita: quantita, prezzo_cents: 10000, sconto: sconto)
    documento.documento_righe.create!(riga: riga)
    documento
  end

  def prossimo_numero
    @numero = (@numero || 1000) + 1
  end

  def ricalcola
    @libro.ricalcola_giacenza!
    Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id)
  end
end
```

Nota: se la fixture `categorie(:scolastica)` non esiste con quel nome, apri `test/fixtures/categorie.yml` e usa il primo nome disponibile.

- [ ] **Step 4.2: Esegui il test e verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/giacenza_test.rb`
Expected: FAIL — `uninitialized constant Giacenza` / `undefined method 'ricalcola_giacenza!'`

- [ ] **Step 4.3: Implementa Giacenza**

Crea `app/models/giacenza.rb`:

```ruby
class Giacenza < ApplicationRecord
  self.table_name = "giacenze"

  include AccountScoped

  belongs_to :libro

  # Sospensione dei trigger per-riga durante gli import bulk
  thread_mattr_accessor :ricalcolo_sospeso

  def self.sospendi_ricalcolo
    self.ricalcolo_sospeso = true
    yield
  ensure
    self.ricalcolo_sospeso = false
  end

  # Contatori canonici, tutti derivati dal segno fisico (Causale::SEGNO_SQL):
  # - disponibile: carichi subito + vendite alla consegna (magazzino vendita)
  # - campionario: tutto, senza gating
  # - impegnato: residui delle vendite non consegnate
  # - venduto: copie e importo (al prezzo scontato) delle vendite consegnate
  AGGREGATI_SQL = <<~SQL.freeze
    COALESCE(SUM(
      CASE causali.tipo_movimento
        WHEN 2 THEN (#{Causale::SEGNO_SQL}) * righe.quantita
        WHEN 1 THEN (#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0)
        ELSE 0
      END
    ) FILTER (WHERE causali.magazzino = 'vendita'), 0)::integer AS disponibile,
    COALESCE(SUM((#{Causale::SEGNO_SQL}) * righe.quantita)
      FILTER (WHERE causali.magazzino = 'campionario'), 0)::integer AS campionario,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1), 0)::integer AS impegnato,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1), 0)::integer AS venduto_copie,
    COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0) *
        (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))
      FILTER (WHERE causali.magazzino = 'vendita' AND causali.tipo_movimento = 1)), 0)::bigint AS venduto_cents
  SQL

  # Solo documenti padre: i figli condividono le righe del padre (mai doppi conteggi)
  FONTE_SQL = <<~SQL.freeze
    FROM documento_righe
    JOIN righe ON righe.id = documento_righe.riga_id
    JOIN documenti ON documenti.id = documento_righe.documento_id
    JOIN causali ON causali.id = documenti.causale_id
    LEFT JOIN LATERAL (
      SELECT SUM(cr.quantita) AS consegnate
      FROM consegna_righe cr
      WHERE cr.documento_riga_id = documento_righe.id
    ) cons ON true
    WHERE documenti.account_id = :account_id
      AND documenti.documento_padre_id IS NULL
  SQL

  # Ricalcolo full-from-scratch per libro: idempotente, mai drift
  def ricalcola!
    sql = ActiveRecord::Base.sanitize_sql_array([
      "SELECT #{AGGREGATI_SQL} #{FONTE_SQL} AND righe.libro_id = :libro_id",
      { account_id: account_id, libro_id: libro_id, divisore: self.class.divisore_sconto(account) }
    ])
    update!(self.class.connection.select_one(sql))
  end

  # Bulk per import/backfill: una INSERT ... ON CONFLICT per tutto l'account
  def self.ricalcola_tutte!(account)
    sql = sanitize_sql_array([<<~SQL, { account_id: account.id, divisore: divisore_sconto(account) }])
      INSERT INTO giacenze (id, account_id, libro_id, disponibile, campionario, impegnato,
                            venduto_copie, venduto_cents, created_at, updated_at)
      SELECT gen_random_uuid(), :account_id, righe.libro_id, #{AGGREGATI_SQL}, NOW(), NOW()
      #{FONTE_SQL}
      GROUP BY righe.libro_id
      ON CONFLICT (account_id, libro_id) DO UPDATE SET
        disponibile = EXCLUDED.disponibile,
        campionario = EXCLUDED.campionario,
        impegnato = EXCLUDED.impegnato,
        venduto_copie = EXCLUDED.venduto_copie,
        venduto_cents = EXCLUDED.venduto_cents,
        updated_at = NOW()
    SQL
    connection.execute(sql)
  end

  def self.divisore_sconto(account)
    account.azienda&.sconto_defiscalizzato? ? 104.0 : 100.0
  end
end
```

In `app/models/libro.rb`, subito dopo `has_many :documento_righe, through: :righe` aggiungi:

```ruby
  # Crea-o-ricalcola la giacenza per questo libro (pattern saldo!)
  def ricalcola_giacenza!
    return if Giacenza.ricalcolo_sospeso
    Giacenza.find_or_create_by!(account_id: account_id, libro_id: id).ricalcola!
  end
```

(NON toccare ancora `has_one :giacenza, class_name: "Views::Giacenza"` — la UI legge ancora la vista; lo switch è nel Task 7.)

- [ ] **Step 4.4: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/giacenza_test.rb`
Expected: PASS (11 test)

- [ ] **Step 4.5: Rake task di backfill/recovery + backfill dev**

Crea `lib/tasks/magazzino.rake`:

```ruby
namespace :magazzino do
  desc "Ricalcola tutte le giacenze per ogni account (backfill/recovery)"
  task ricalcola_giacenze: :environment do
    Account.find_each do |account|
      Giacenza.ricalcola_tutte!(account)
      puts "Account #{account.id}: #{Giacenza.where(account_id: account.id).count} giacenze"
    end
  end
end
```

Run: `docker exec prova-app-1 bin/rails magazzino:ricalcola_giacenze`
Expected: stampa un conteggio > 0 per l'account principale

Verifica a campione contro la vista legacy (i numeri NON devono coincidere alla pari — semantica diversa — ma devono essere plausibili):
`docker exec prova-app-1 bin/rails runner 'g = Giacenza.order(venduto_copie: :desc).first; puts g.attributes.inspect'`

- [ ] **Step 4.6: Commit**

```bash
git add app/models lib/tasks/magazzino.rake test/models/giacenza_test.rb
git commit -m "feat(magazzino): tabella giacenze con ricalcolo idempotente per libro"
```

---

### Task 5: Acconti — Pagabile has_many + tipo_pagamento_previsto

**Files:**
- Modify: `app/models/pagamento.rb`
- Modify: `app/models/concerns/pagabile.rb` (riscrittura)
- Modify: `app/models/documento.rb` (propagazione alla saturazione)
- Modify: `app/models/saldo.rb:34` (patch interim `:pagamento` → `:pagamenti`)
- Modify: `app/controllers/documenti/pagamento_controller.rb`
- Modify: `app/controllers/documenti_controller.rb` (permit)
- Modify: `app/views/documenti/container/_content.html.erb` (select previsto)
- Modify (sweep `:pagamento` → `:pagamenti`): vedi step 5.5
- Create: `test/models/concerns/pagabile_test.rb`

- [ ] **Step 5.1: Scrivi il test**

Crea `test/models/concerns/pagabile_test.rb`:

```ruby
require "test_helper"

class PagabileTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @documento = documenti(:fattura_uno) # totale 200000
  end

  teardown do
    Current.reset
  end

  test "mark_pagato salda il residuo in un colpo" do
    @documento.mark_pagato(tipo_pagamento: "contanti")

    assert @documento.pagato?
    assert_not @documento.parzialmente_pagato?
    assert_equal 1, @documento.pagamenti.count
    assert_equal 200000, @documento.pagamenti.first.importo_cents
    assert_equal 0, @documento.residuo_da_pagare_cents
  end

  test "mark_pagato è idempotente" do
    @documento.mark_pagato(tipo_pagamento: "contanti")
    assert_no_difference -> { Pagamento.count } do
      @documento.mark_pagato(tipo_pagamento: "contanti")
    end
  end

  test "registra_acconto! lascia il residuo e lo stato parziale" do
    @documento.registra_acconto!(importo_cents: 50000, tipo_pagamento: "bonifico")

    assert_not @documento.pagato?
    assert @documento.parzialmente_pagato?
    assert_equal 150000, @documento.residuo_da_pagare_cents
  end

  test "acconti successivi saturano il documento" do
    @documento.registra_acconto!(importo_cents: 50000)
    @documento.registra_acconto!(importo_cents: 150000)

    assert @documento.pagato?
    assert_equal 2, @documento.pagamenti.count
  end

  test "acconto oltre il residuo solleva ArgumentError" do
    @documento.registra_acconto!(importo_cents: 150000)

    assert_raises(ArgumentError) do
      @documento.registra_acconto!(importo_cents: 60000)
    end
  end

  test "tipo_pagamento_previsto fa da default per gli acconti" do
    @documento.update!(tipo_pagamento_previsto: "cedole")
    @documento.mark_pagato

    assert_equal "cedole", @documento.pagamenti.first.tipo_pagamento
    assert_equal "cedole", @documento.tipo_pagamento
  end

  test "il tipo esplicito vince sul previsto" do
    @documento.update!(tipo_pagamento_previsto: "cedole")
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "contanti")

    assert_equal "contanti", @documento.pagamenti.first.tipo_pagamento
  end

  test "tipo_pagamento in lettura è quello dell'ultimo pagamento" do
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "contanti", pagato_il: 2.days.ago)
    @documento.registra_acconto!(importo_cents: 1000, tipo_pagamento: "bonifico", pagato_il: 1.day.ago)

    assert_equal "bonifico", @documento.tipo_pagamento
  end

  test "documento a totale zero non è pagato da solo, lo diventa con mark" do
    doc = Documento.create!(account: accounts(:fizzy), user: users(:one),
                            causale: causali(:fattura), clientable: clienti(:cliente_fizzy),
                            numero_documento: 998, data_documento: Date.today)
    assert_not doc.pagato?

    doc.mark_pagato
    assert doc.pagato?
  end

  test "unmark_pagato distrugge un acconto specifico" do
    primo = @documento.registra_acconto!(importo_cents: 50000)
    @documento.registra_acconto!(importo_cents: 150000)

    @documento.unmark_pagato(primo)

    assert_not @documento.pagato?
    assert_equal 50000, @documento.residuo_da_pagare_cents
  end

  test "la saturazione propaga il pagamento ai figli col tipo dell'ultimo acconto" do
    figlio = documenti(:ordine_figlio) # padre: fattura_uno

    @documento.registra_acconto!(importo_cents: 50000, tipo_pagamento: "contanti")
    assert_not figlio.reload.pagato?, "l'acconto parziale non deve propagare"

    @documento.registra_acconto!(importo_cents: 150000, tipo_pagamento: "cedole")
    assert figlio.reload.pagato?, "la saturazione deve propagare"
    assert_equal "cedole", figlio.tipo_pagamento
  end

  test "pagato e consegnato insieme chiudono il documento" do
    @documento.mark_consegnato
    @documento.mark_pagato(tipo_pagamento: "contanti")

    assert @documento.reload.closed?
  end
end
```

- [ ] **Step 5.2: Esegui il test e verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/concerns/pagabile_test.rb`
Expected: FAIL — `undefined method 'pagamenti'` / `registra_acconto!`

- [ ] **Step 5.3: Implementa Pagamento e Pagabile**

In `app/models/pagamento.rb` rimuovi `validates :pagabile_id, uniqueness: { scope: :pagabile_type }` e aggiungi:

```ruby
  validates :importo_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
```

Riscrivi `app/models/concerns/pagabile.rb`:

```ruby
module Pagabile
  extend ActiveSupport::Concern

  included do
    has_many :pagamenti, as: :pagabile, dependent: :destroy
  end

  # Fast path: salda il residuo in un click
  def mark_pagato(user: Current.user, pagato_il: nil, tipo_pagamento: nil)
    return if pagato?
    registra_acconto!(importo_cents: residuo_da_pagare_cents, tipo_pagamento: tipo_pagamento,
                      pagato_il: pagato_il, user: user)
  end

  # Acconto libero per importo; il tipo previsto sul documento fa da default
  def registra_acconto!(importo_cents:, tipo_pagamento: nil, pagato_il: nil, user: Current.user)
    importo_cents = importo_cents.to_i
    residuo = residuo_da_pagare_cents
    raise ArgumentError, "importo #{importo_cents} negativo" if importo_cents.negative?
    raise ArgumentError, "importo #{importo_cents} oltre il residuo #{residuo}" if importo_cents > residuo

    pagamento = pagamenti.create!(
      importo_cents: importo_cents,
      tipo_pagamento: tipo_pagamento.presence || try(:tipo_pagamento_previsto),
      pagato_il: pagato_il || Time.current,
      user: user
    )
    dopo_variazione_pagamenti
    pagamento
  end

  def unmark_pagato(pagamento = nil)
    (pagamento || pagamenti.order(:pagato_il).last)&.destroy
    dopo_variazione_pagamenti
  end

  def pagato?
    pagamenti.any? && residuo_da_pagare_cents <= 0
  end

  def parzialmente_pagato?
    pagamenti.any? && residuo_da_pagare_cents.positive?
  end

  def residuo_da_pagare_cents
    (try(:totale_cents) || 0) - pagamenti.sum(:importo_cents)
  end

  def pagato_il
    pagamenti.maximum(:pagato_il)
  end

  def tipo_pagamento
    pagamenti.order(:pagato_il).last&.tipo_pagamento
  end

  private

  def dopo_variazione_pagamenti
    pagamenti.reset
    ricalcola_saldo_clientable
    pagamento_saturato if pagato? && respond_to?(:pagamento_saturato)
    auto_close_se_completo if respond_to?(:auto_close_se_completo)
  end

  def ricalcola_saldo_clientable
    clientable = try(:clientable)
    clientable.ricalcola_saldo! if clientable.respond_to?(:ricalcola_saldo!)
  end
end
```

- [ ] **Step 5.4: Adegua Documento (propagazione alla saturazione)**

In `app/models/documento.rb`:

1. Rimuovi `after_save :propaga_pagamento_ai_figli, if: :just_marked_pagato?` e il metodo privato `just_marked_pagato?`.
2. Aggiungi il metodo pubblico hook (vicino a `auto_close_se_completo`):

```ruby
  # Chiamato da Pagabile quando il documento risulta interamente pagato:
  # i figli vengono saldati col tipo dell'ultimo acconto
  def pagamento_saturato
    ultimo = pagamenti.order(:pagato_il).last
    tutti_i_discendenti.each do |figlio|
      figlio.mark_pagato(user: ultimo&.user || Current.user, tipo_pagamento: ultimo&.tipo_pagamento)
    end
  end
```

3. Elimina il vecchio metodo privato `propaga_pagamento_ai_figli`.
4. In `form_steps`, aggiungi `:tipo_pagamento_previsto` allo step `tipo_documento`:

```ruby
      tipo_documento: %i[causale_id numero_documento data_documento clientable_type clientable_id tipo_pagamento_previsto],
```

- [ ] **Step 5.5: Sweep `:pagamento` → `:pagamenti` nei reader**

- `app/models/saldo.rb:34` → `da_pagare = documenti.left_joins(:pagamenti).where(pagamenti: { id: nil })`
- `app/controllers/documenti_controller.rb:39`
- `app/controllers/agenda_controller.rb:208,299,316`
- `app/controllers/vendite_controller.rb:46` (`where.missing(:pagamento)` → `where.missing(:pagamenti)`)
- `app/controllers/documenti/bulk_pagamenti_controller.rb:39,45`
- `app/controllers/documenti/bulk_derivazioni_controller.rb:10`
- `app/controllers/documenti/bulk_stati_controller.rb:7`
- `app/controllers/entries/bulk_gestione_controller.rb:9`
- `app/controllers/documenti/bulk_gestione_controller.rb:7`
- `app/models/entry.rb:147`
- `app/models/clienti/presenter.rb:14`
- `app/models/filters/documento_filter.rb:47,65,118` (rename) e `:79,83`: `joins(:pagamento)` → `joins(:pagamenti).distinct` (un documento può avere più acconti)
- `app/tools/mcp_tools/vendite_per_libro.rb:84`
- `app/tools/mcp_tools/documenti_list.rb:40` (`joins(:pagamenti).distinct`), `:57,64`

Verifica: `grep -rn "includes(:.*:pagamento[^_i]\|left_joins(:pagamento[^_i]\|missing(:pagamento)\|joins(:pagamento)" app/ lib/`
Expected: nessun risultato

- [ ] **Step 5.6: Form + controller**

In `app/views/documenti/container/_content.html.erb`, dentro il blocco Causale/Numero/Data (dopo il `</div>` del form-field della data, riga ~77, prima della chiusura del flex), aggiungi:

```erb
        <div class="form-field" style="flex: 1 1 25%;">
          <%= form.label :tipo_pagamento_previsto, "Pagamento previsto", class: "form-label" %>
          <%= form.select :tipo_pagamento_previsto,
              options_for_select(Pagamento::TIPI_PAGAMENTO.map { |k, v| [v, k] }, documento.tipo_pagamento_previsto),
              { include_blank: "nessuno" },
              class: "input input--select" %>
        </div>
```

In `app/controllers/documenti_controller.rb:177` aggiungi `:tipo_pagamento_previsto` alla lista permit.

In `app/controllers/documenti/pagamento_controller.rb`:

`create` diventa (acconto se arriva l'importo, altrimenti fast path):

```ruby
    # POST /documenti/:documento_id/pagamento
    # params[:importo] opzionale (euro): registra un acconto invece di saldare
    def create
      if params[:importo].present?
        @documento.registra_acconto!(
          importo_cents: (BigDecimal(params[:importo].to_s) * 100).to_i,
          tipo_pagamento: params[:tipo_pagamento],
          pagato_il: parsed_date(:pagato_il)
        )
      else
        @documento.mark_pagato(pagato_il: parsed_date(:pagato_il), tipo_pagamento: params[:tipo_pagamento])
      end

      respond_to do |format|
        format.turbo_stream { render_container_replacement }
        format.html { redirect_back fallback_location: documento_path(@documento) }
        format.json { render json: { ok: true, pagato: @documento.pagato?, pagato_il: @documento.pagato_il, tipo_pagamento: @documento.tipo_pagamento, residuo_cents: @documento.residuo_da_pagare_cents } }
      end
    end
```

`update` (riga 25): `@documento.pagamento&.update!(...)` → `@documento.pagamenti.order(:pagato_il).last&.update!(pagato_il: parsed_date(:pagato_il), tipo_pagamento: params[:tipo_pagamento])`; nel json usa `@documento.pagato_il` / `@documento.tipo_pagamento`.

- [ ] **Step 5.7: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/concerns/pagabile_test.rb`
Expected: PASS

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

- [ ] **Step 5.8: Commit**

```bash
git add app/ test/
git commit -m "feat(pagamenti): acconti per importo + tipo_pagamento_previsto"
```

---

### Task 6: Trigger giacenza + Saldo sui residui

**Files:**
- Modify: `app/models/documento_riga.rb`, `app/models/riga.rb`, `app/models/documento.rb`
- Modify: `app/models/concerns/consegnabile.rb` (hook giacenza)
- Modify: `app/models/saldo.rb` (riscrittura ricalcolo)
- Modify: `app/services/imports/documenti_processor.rb`
- Modify: `test/models/giacenza_test.rb` (test trigger), `test/models/saldo_test.rb`

- [ ] **Step 6.1: Scrivi i test dei trigger**

Aggiungi in fondo a `test/models/giacenza_test.rb` (prima di `private`):

```ruby
  test "creare e distruggere una documento_riga ricalcola la giacenza" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    assert_equal 10, Giacenza.find_by!(libro_id: @libro.id).disponibile

    Documento.last.documento_righe.first.destroy
    assert_equal 0, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "aggiornare la quantita di una riga ricalcola la giacenza" do
    doc = crea_documento(causali(:carico_fornitore), quantita: 10)
    doc.righe.first.update!(quantita: 25)

    assert_equal 25, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "la consegna ricalcola la giacenza dei libri del documento" do
    crea_documento(causali(:carico_fornitore), quantita: 10)
    vendita = crea_documento(causali(:fattura), quantita: 4)
    vendita.mark_consegnato

    giacenza = Giacenza.find_by!(libro_id: @libro.id)
    assert_equal 6, giacenza.disponibile
    assert_equal 4, giacenza.venduto_copie
  end

  test "distruggere un documento ricalcola la giacenza" do
    doc = crea_documento(causali(:carico_fornitore), quantita: 10)
    doc.destroy!

    assert_equal 0, Giacenza.find_by!(libro_id: @libro.id).disponibile
  end

  test "sospendi_ricalcolo salta i trigger per-riga" do
    Giacenza.sospendi_ricalcolo do
      crea_documento(causali(:carico_fornitore), quantita: 10)
    end
    assert_nil Giacenza.find_by(libro_id: @libro.id)

    Giacenza.ricalcola_tutte!(@account)
    assert_equal 10, Giacenza.find_by!(account_id: @account.id, libro_id: @libro.id).disponibile
  end
```

Run: `docker exec prova-app-1 bin/rails test test/models/giacenza_test.rb`
Expected: FAIL sui 5 nuovi test (nessun trigger esiste ancora)

- [ ] **Step 6.2: Implementa i trigger**

In `app/models/documento_riga.rb`, dopo `after_destroy_commit :rientra_bolla_visione_riga`:

```ruby
  after_create_commit :ricalcola_giacenza_libro
  after_destroy_commit :ricalcola_giacenza_libro
```

e tra i metodi privati:

```ruby
  def ricalcola_giacenza_libro
    riga&.libro&.ricalcola_giacenza!
  end
```

In `app/models/riga.rb`, dopo `after_destroy :aggiorna_totali_documenti`:

```ruby
  after_update_commit :ricalcola_giacenze_libri
```

e tra i metodi privati:

```ruby
    def ricalcola_giacenze_libri
      return unless saved_change_to_quantita? || saved_change_to_prezzo_cents? ||
                    saved_change_to_sconto? || saved_change_to_libro_id?

      libro.ricalcola_giacenza!
      if (vecchio_libro_id = saved_change_to_libro_id&.first)
        Libro.find_by(id: vecchio_libro_id)&.ricalcola_giacenza!
      end
    end
```

In `app/models/documento.rb`:

1. Callback (accanto agli altri `after_*`):

```ruby
  before_destroy :memorizza_libri_per_giacenza, prepend: true
  after_destroy_commit :ricalcola_giacenze_libri_memorizzati
  after_update_commit :ricalcola_giacenze_libri, if: -> { saved_change_to_causale_id? || saved_change_to_documento_padre_id? }
```

2. Metodo pubblico (lo usa anche Consegnabile):

```ruby
  # Ricalcola la giacenza di tutti i libri toccati da questo documento
  def ricalcola_giacenze_libri
    Libro.where(id: righe.select(:libro_id)).find_each(&:ricalcola_giacenza!)
  end
```

3. Metodi privati:

```ruby
  def memorizza_libri_per_giacenza
    @libri_da_ricalcolare = righe.pluck(:libro_id).uniq
  end

  def ricalcola_giacenze_libri_memorizzati
    Libro.where(id: @libri_da_ricalcolare.to_a).find_each(&:ricalcola_giacenza!)
  end
```

In `app/models/concerns/consegnabile.rb`, dentro `dopo_variazione_consegne`, dopo `ricalcola_saldo_clientable`:

```ruby
    ricalcola_giacenze_libri if respond_to?(:ricalcola_giacenze_libri)
```

- [ ] **Step 6.3: Importer bulk**

In `app/services/imports/documenti_processor.rb`, avvolgi `process_file` (metodo protected in testa alla classe):

```ruby
    def process_file
      Giacenza.sospendi_ricalcolo do
        case detected_format
        when "xml"
          process_xml
        when "pdf"
          process_ndc_pdf
        else
          process_excel
        end
      end
      Giacenza.ricalcola_tutte!(@account)
    end
```

- [ ] **Step 6.4: Riscrivi Saldo sui residui**

Riscrivi il corpo di `Saldo` (`app/models/saldo.rb`, conserva header annotate, `self.table_name`, `include AccountScoped`, `belongs_to`):

```ruby
  # Residui reali: consegne per riga (valorizzate al prezzo scontato),
  # pagamenti per importo. Segno monetario = -segno fisico:
  # uscita = il cliente deve (+), entrata = credito (-). Solo documenti padre.
  def ricalcola!
    update!(residui_consegne.merge(residui_pagamenti))
  end

  private

  def residui_consegne
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, bind_params])
      SELECT
        COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0))), 0)::integer AS copie_da_consegnare,
        COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)) *
          (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))), 0)::bigint AS importo_da_consegnare_cents
      FROM documenti
      JOIN causali ON causali.id = documenti.causale_id
      JOIN documento_righe ON documento_righe.documento_id = documenti.id
      JOIN righe ON righe.id = documento_righe.riga_id
      LEFT JOIN LATERAL (
        SELECT SUM(cr.quantita) AS consegnate
        FROM consegna_righe cr
        WHERE cr.documento_riga_id = documento_righe.id
      ) cons ON true
      WHERE documenti.clientable_type = :saldabile_type
        AND documenti.clientable_id = :saldabile_id
        AND documenti.account_id = :account_id
        AND documenti.documento_padre_id IS NULL
    SQL
    self.class.connection.select_one(sql)
  end

  def residui_pagamenti
    sql = ActiveRecord::Base.sanitize_sql_array([<<~SQL, bind_params])
      SELECT
        COALESCE(SUM(CASE WHEN COALESCE(pag.importo_pagato, 0) < COALESCE(documenti.totale_cents, 0)
                          THEN -(#{Causale::SEGNO_SQL}) * COALESCE(documenti.totale_copie, 0)
                          ELSE 0 END), 0)::integer AS copie_da_pagare,
        COALESCE(SUM(-(#{Causale::SEGNO_SQL}) *
          (COALESCE(documenti.totale_cents, 0) - COALESCE(pag.importo_pagato, 0))), 0)::bigint AS importo_da_pagare_cents
      FROM documenti
      JOIN causali ON causali.id = documenti.causale_id
      LEFT JOIN LATERAL (
        SELECT SUM(p.importo_cents) AS importo_pagato
        FROM pagamenti p
        WHERE p.pagabile_type = 'Documento' AND p.pagabile_id = documenti.id
      ) pag ON true
      WHERE documenti.clientable_type = :saldabile_type
        AND documenti.clientable_id = :saldabile_id
        AND documenti.account_id = :account_id
        AND documenti.documento_padre_id IS NULL
    SQL
    self.class.connection.select_one(sql)
  end

  def bind_params
    { saldabile_type: saldabile_type, saldabile_id: saldabile_id, account_id: account_id,
      divisore: Giacenza.divisore_sconto(account) }
  end
```

- [ ] **Step 6.5: Aggiorna saldo_test per gli acconti**

Le aspettative numeriche esistenti restano valide (le fixture righe del Task 3 valgono esattamente i `totale_cents` dei documenti, sconto 0). Aggiungi in fondo a `test/models/saldo_test.rb` (prima dell'ultima `end`):

```ruby
  # --- Residui parziali ---

  test "un acconto riduce importo_da_pagare del suo importo" do
    @cliente.ricalcola_saldo!
    prima = @cliente.saldo.reload.importo_da_pagare_cents

    documenti(:fattura_uno).registra_acconto!(importo_cents: 50000)

    saldo = @cliente.saldo.reload
    assert_equal prima - 50000, saldo.importo_da_pagare_cents
    # copie: il documento non è saturo, le sue copie restano da pagare
    assert_equal 42, saldo.copie_da_pagare
  end

  test "una consegna parziale riduce i residui da consegnare per riga" do
    @cliente.ricalcola_saldo!
    prima_copie = @cliente.saldo.reload.copie_da_consegnare

    doc = documenti(:fattura_uno)
    doc.consegna_parziale!({ documento_righe(:dr_fattura_uno).id => 12 })

    saldo = @cliente.saldo.reload
    assert_equal prima_copie - 12, saldo.copie_da_consegnare
    assert_equal 420000 - 120000, saldo.importo_da_consegnare_cents
  end
```

E aggiungi `:libri, :categorie, :righe, :documento_righe` alla riga `fixtures` in testa al file.

- [ ] **Step 6.6: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/giacenza_test.rb test/models/saldo_test.rb`
Expected: PASS

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

- [ ] **Step 6.7: Commit**

```bash
git add app/ test/
git commit -m "feat(magazzino): trigger di ricalcolo giacenza + saldo sui residui reali"
```

---

### Task 7: Switch UI — la giacenza si legge dalla tabella

**Files:**
- Modify: `app/models/libro.rb:80` (associazione)
- Modify: `app/helpers/libri_helper.rb:31`
- Modify: `app/views/titoli/show.html.erb:139-158`
- Modify: `app/controllers/libri_controller.rb` (includes)
- Modify: `app/views/libri/show.html.erb:22`, `app/views/libri/update.turbo_stream.erb:2`, `app/views/libri/edit.html.erb:18`, `app/views/libri/container/_container.html.erb:1`

- [ ] **Step 7.1: Sostituisci l'associazione**

In `app/models/libro.rb` sostituisci:

```ruby
  has_one :giacenza, class_name: "Views::Giacenza", primary_key: "id", foreign_key: "libro_id"
```

con:

```ruby
  has_one :giacenza, dependent: :destroy
```

- [ ] **Step 7.2: Badge helper**

In `app/helpers/libri_helper.rb:31` sostituisci:

```ruby
    return "badge--warning" if libro.giacenza&.ordini.to_i.positive?
```

con:

```ruby
    return "badge--warning" if libro.giacenza&.impegnato.to_i.positive?
```

- [ ] **Step 7.3: titoli/show — contatori nuovi**

In `app/views/titoli/show.html.erb` (blocco righe 139-158) sostituisci i tre riquadri Carichi/Ordini/Vendite con i contatori canonici:

```erb
      <div class="flex gap flex-wrap">
        <div class="flex flex-column align-center pad fill-shade border-radius" style="min-width: 80px;">
          <span class="txt-x-large font-weight-black txt-accent"><%= @libro.giacenza.disponibile %></span>
          <span class="txt-xx-small txt-subtle">Disponibile</span>
        </div>
        <div class="flex flex-column align-center pad fill-shade border-radius" style="min-width: 80px;">
          <span class="txt-x-large font-weight-black txt-negative"><%= @libro.giacenza.impegnato %></span>
          <span class="txt-xx-small txt-subtle">Impegnato</span>
        </div>
        <div class="flex flex-column align-center pad fill-shade border-radius" style="min-width: 80px;">
          <span class="txt-x-large font-weight-black txt-link"><%= @libro.giacenza.venduto_copie %></span>
          <span class="txt-xx-small txt-subtle">Venduto</span>
        </div>
      </div>
```

- [ ] **Step 7.4: Pulizia locals + includes**

- `app/views/libri/container/_container.html.erb:1`: togli `giacenza: nil` dai locals (non è usato nel partial).
- `app/views/libri/show.html.erb:22`: `render "libri/container/container", libro: @libro, suggeriti: @suggeriti_fascicoli` (togli `giacenza:`).
- `app/views/libri/update.turbo_stream.erb:2`: `render "libri/container/container", libro: @libro` (togli `giacenza:`).
- `app/views/libri/edit.html.erb:18`: elimina la riga `@giacenza = @libro.giacenza` dal blocco `<% %>` (resta `@movimenti`).
- `app/controllers/libri_controller.rb#show:49`: lascia `@giacenza = @libro.giacenza` (ora legge la tabella) oppure eliminala se nessuna vista la usa più — verifica con `grep -n "@giacenza" app/views/libri/ -r` e agisci di conseguenza.
- `app/controllers/libri_controller.rb#index`: nel ramo non-JSON aggiungi il preload per il badge: `set_page_and_extract_portion_from @filter.libri.includes(:giacenza)` (e nel ramo `params[:q]`: `libri = Current.account.libri.search_all_word(params[:q]).includes(:giacenza)`).

- [ ] **Step 7.5: Verifica manuale + suite**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

Verifica a mano su dev (`bin/dev` già attivo): apri un libro con movimenti — la card e il pannello Giacenza in `titoli#show` mostrano Disponibile/Impegnato/Venduto coerenti.

- [ ] **Step 7.6: Commit**

```bash
git add app/
git commit -m "feat(libri): la UI legge la giacenza dalla tabella, badge su impegnato"
```

---

### Task 8: Libro::Movimenti — reader allineato

**Files:**
- Modify: `app/models/libro/movimenti.rb`

Call site invariati (`Libro::Movimenti.new(@libro)` in `libri_controller.rb:50`, `libri/movimenti_controller.rb:7`, `libri/edit.html.erb:19`): il nuovo parametro `account:` ha default `Current.account`.

- [ ] **Step 8.1: Riscrivi Movimenti**

```ruby
# app/models/libro/movimenti.rb
#
# Reader di dettaglio: liste righe + riepilogo per anno.
# I contatori canonici vivono in Giacenza; qui stessa semantica, stesso segno (Causale).
class Libro::Movimenti
  attr_reader :libro, :account

  def initialize(libro, account: Current.account)
    @libro = libro
    @account = account
  end

  # Righe da documenti attivi con residuo da consegnare: complemento esatto di "impegnato"
  def da_consegnare
    righe_base.merge(Documento.attivi).where(<<~SQL)
      righe.quantita > COALESCE((
        SELECT SUM(cr.quantita) FROM consegna_righe cr
        WHERE cr.documento_riga_id = documento_righe.id
      ), 0)
    SQL
  end

  # Righe da documenti chiusi (con closure)
  def completati
    righe_base.merge(Documento.completati)
  end

  # Rete di sicurezza: tutto ciò che è in righe_base deve comparire da qualche parte
  def altri
    esclusi = (da_consegnare.to_a + completati.to_a).map(&:id).to_set
    righe_base.to_a.reject { |dr| esclusi.include?(dr.id) }
  end

  # { 2024 => { carichi:, vendite_clienti:, vendite_scuole:, importo: }, ... }
  def riepilogo_per_anno
    all_righe = righe_base.to_a
    grouped = all_righe.group_by { |dr| dr.documento.data_documento&.year }
    grouped.transform_values { |drs| aggregate(drs) }
           .sort_by { |anno, _| -anno.to_i }
           .to_h
  end

  private

  def righe_base
    DocumentoRiga
      .joins(:riga, documento: :causale)
      .includes(:riga, documento: [:causale, :consegne])
      .where(riga: { libro_id: libro.id })
      .where(documenti: { documento_padre_id: nil, account_id: account.id })
      .order("documenti.data_documento DESC")
  end

  def aggregate(documento_righe)
    result = Hash.new(0)
    documento_righe.each do |dr|
      causale = dr.documento.causale
      next unless causale

      if causale.carico?
        result[:carichi] += dr.riga.quantita * causale.segno
      elsif causale.vendita?
        qta = dr.riga.quantita * -causale.segno
        if dr.documento.clientable_type == "Cliente"
          result[:vendite_clienti] += qta
        else
          result[:vendite_scuole] += qta
        end
        result[:importo] += dr.riga.importo_cents * -causale.segno
      end
    end
    result
  end
end
```

(`segno_per` eliminato: le vendite usano `-causale.segno` — segno monetario — i carichi il segno fisico; identico all'aritmetica precedente.)

- [ ] **Step 8.2: Suite + verifica manuale**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

Verifica manuale: `libri#show` di un libro movimentato — footer e riepilogo per anno con gli stessi numeri di prima; un documento con consegna parziale compare in "da consegnare".

- [ ] **Step 8.3: Commit**

```bash
git add app/models/libro/movimenti.rb
git commit -m "refactor(movimenti): scoping account, segno da Causale, da_consegnare sui residui"
```

---

### Task 9: Export — Libro::Situazione al posto del crosstab

**Files:**
- Create: `app/models/libro/situazione.rb`
- Create: `test/models/libro/situazione_test.rb`
- Create: `app/views/libri/situazione.xlsx.axlsx`
- Modify: `app/controllers/libri_controller.rb` (azione), `config/routes.rb:313`
- Delete: `app/views/libri/crosstab.xlsx.axlsx`, metodo `Libro.crosstab`

- [ ] **Step 9.1: Scrivi il test**

Crea `test/models/libro/situazione_test.rb`:

```ruby
require "test_helper"

class Libro::SituazioneTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :documenti,
           :libri, :categorie, :editori, :righe, :documento_righe

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
    @situazione = Libro::Situazione.new(accounts(:fizzy))
  end

  teardown do
    Current.reset
  end

  test "una colonna per ogni causale, quantità aggregate" do
    riga = @situazione.righe.find { |r| r["id"] == libri(:libro_fizzy).id }

    assert riga, "libro_fizzy deve comparire"
    # fixture per libro_fizzy (padre-nil): Vendita 10, TD01 20+15, TD04 3
    assert_equal 10, riga["Vendita"]
    assert_equal 35, riga["TD01"]
    assert_equal 3, riga["TD04"]
    assert_equal libri(:libro_fizzy).codice_isbn, riga["codice_isbn"]
  end

  test "esclude i documenti figli" do
    riga = @situazione.righe.find { |r| r["id"] == libri(:libro_fizzy).id }
    # ordine_figlio (8 copie, causale Ordine) ha documento_padre: escluso
    assert_equal 0, riga["Ordine"]
  end

  test "esclude gli altri account" do
    ids = @situazione.righe.map { |r| r["id"] }
    assert_not_includes ids, libri(:libro_acme).id
  end

  test "le intestazioni contengono libro, causali e anagrafica" do
    intestazioni = @situazione.righe.first.keys
    assert_includes intestazioni, "titolo"
    assert_includes intestazioni, "TD01"
    assert_includes intestazioni, "editore"
  end
end
```

- [ ] **Step 9.2: Esegui il test e verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/libro/situazione_test.rb`
Expected: FAIL — `uninitialized constant Libro::Situazione`

- [ ] **Step 9.3: Implementa il query object**

Crea `app/models/libro/situazione.rb`:

```ruby
# Situazione di magazzino per l'export xlsx: una colonna per causale.
# Sostituisce Libro.crosstab: niente estensione crosstab(), bind params,
# solo documenti padre, scoping account. Pivot in Ruby.
class Libro::Situazione
  def initialize(account)
    @account = account
  end

  def causali
    @causali ||= Causale.order(:magazzino, :movimento, :tipo_movimento).pluck(:causale)
  end

  def righe
    quantita = quantita_per_libro_e_causale

    @account.libri.where(id: quantita.keys)
      .includes(:editore, :categoria).order(:titolo)
      .map do |libro|
        per_causale = quantita.fetch(libro.id, {})
        {
          "codice_isbn" => libro.codice_isbn,
          "titolo" => libro.titolo,
          "prezzo_in_cents" => libro.prezzo_in_cents,
          **causali.index_with { |causale| per_causale.fetch(causale, 0) },
          "gruppo" => libro.editore&.gruppo,
          "editore" => libro.editore&.editore,
          "adozioni_count" => libro.adozioni_count,
          "categoria" => libro.categoria&.nome_categoria,
          "classe" => libro.classe,
          "disciplina" => libro.disciplina,
          "id" => libro.id
        }
      end
  end

  private

  def quantita_per_libro_e_causale
    DocumentoRiga
      .joins(:riga, documento: :causale)
      .where(documenti: { account_id: @account.id, documento_padre_id: nil })
      .group("righe.libro_id", "causali.causale")
      .sum("righe.quantita")
      .each_with_object(Hash.new { |h, k| h[k] = {} }) do |((libro_id, causale), quantita), acc|
        acc[libro_id][causale] = quantita
      end
  end
end
```

- [ ] **Step 9.4: Controller, route, vista xlsx**

In `config/routes.rb:313`: `get 'crosstab'` → `get 'situazione'`.

In `app/controllers/libri_controller.rb` sostituisci l'azione `crosstab` con:

```ruby
  def situazione
    @situazione = Libro::Situazione.new(Current.account)
    respond_to do |format|
      format.xlsx
    end
  end
```

Crea `app/views/libri/situazione.xlsx.axlsx`:

```ruby
wb = xlsx_package.workbook

righe = @situazione.righe

wb.add_worksheet(name: "Situazione") do |sheet|
  sheet.add_row(righe.first&.keys || [])

  righe.each do |riga|
    sheet.add_row riga.values, types: [:string]
  end
end
```

Elimina `app/views/libri/crosstab.xlsx.axlsx` e il metodo `Libro.crosstab` (righe 240-280 di `app/models/libro.rb`, incluso il commento `# DA RIVEDERE` se non copre altro — `scarico_fascicoli` resta).

Cerca i link al vecchio path: `grep -rn "crosstab" app/ config/ lib/`
Expected: nessun riferimento residuo a route/metodo (aggiorna eventuali `crosstab_libri_path` → `situazione_libri_path`).

- [ ] **Step 9.5: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/libro/situazione_test.rb`
Expected: PASS

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

Verifica manuale: scarica l'xlsx da `/libri/situazione.xlsx` in dev.

- [ ] **Step 9.6: Commit**

```bash
git add app/ config/routes.rb test/
git rm app/views/libri/crosstab.xlsx.axlsx
git commit -m "feat(export): Libro::Situazione sostituisce il crosstab raw SQL"
```

---

### Task 10: Cleanup finale — vista, file morti, colonne legacy

**Files:**
- Create: `db/migrate/<timestamp>_drop_legacy_magazzino.rb`
- Delete: `app/models/views/giacenza.rb`, `db/views/view_giacenze_v01.sql`, `db/views/view_giacenze_v02.sql`, `app/services/libro_info.rb`, `app/services/libro_situazio.rb`
- Modify: `app/controllers/documenti_controller.rb:177` (permit)

- [ ] **Step 10.1: Verifica che le colonne legacy siano orfane**

Run: `grep -rn "documenti\.status\|\.status\b" app/models/documento.rb app/models/filters/ app/controllers/documenti* app/avo/ 2>/dev/null | grep -v "stato\|status_" | grep -v "^.*#"`
Run: `grep -rn "tipo_pagamento[^_p]" app/avo/ app/models/filters/ | grep -v tipo_pagamento_previsto`

Expected: nessun uso delle **colonne** `documenti.status`, `documenti.consegnato_il`, `documenti.pagato_il`, `documenti.tipo_pagamento` (i **metodi** omonimi vengono dai concern). Se qualcosa emerge (es. un campo Avo), rimuovilo prima di proseguire.

- [ ] **Step 10.2: Migration di drop**

Run: `docker exec prova-app-1 bin/rails generate migration DropLegacyMagazzino`

```ruby
class DropLegacyMagazzino < ActiveRecord::Migration[8.1]
  def up
    # Ricreata a mano in 20260126141155, non più gestita da Scenic: drop diretto.
    # (tablefunc resta installata: la usano le query Blazer)
    execute "DROP VIEW IF EXISTS view_giacenze"

    remove_column :documenti, :status
    remove_column :documenti, :consegnato_il
    remove_column :documenti, :pagato_il
    remove_column :documenti, :tipo_pagamento
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

Run: `docker exec prova-app-1 bin/rails db:migrate && docker exec prova-app-1 bundle exec annotaterb models`

- [ ] **Step 10.3: Elimina i file morti**

```bash
git rm app/models/views/giacenza.rb db/views/view_giacenze_v01.sql db/views/view_giacenze_v02.sql \
       app/services/libro_info.rb app/services/libro_situazio.rb
```

In `app/controllers/documenti_controller.rb:177` togli `:status` (e `:tipo_pagamento` se presente) dal permit.

Verifica riferimenti residui:
Run: `grep -rn "Views::Giacenza\|LibroInfo\|LibroSituazio\|view_giacenze" app/ lib/ config/ test/`
Expected: nessun risultato

- [ ] **Step 10.4: Suite completa + verifica end-to-end**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS

Verifica end-to-end in dev: crea un documento di vendita con 2 righe → il libro mostra `impegnato`; consegna parziale via `POST /documenti/:id/consegna` con `righe` → split impegnato/venduto; acconto via `POST /documenti/:id/pagamento` con `importo` → `parzialmente_pagato?`; saldo del cliente con residui reali.

- [ ] **Step 10.5: Commit**

```bash
git add -A
git commit -m "chore(magazzino): drop view_giacenze, servizi morti e colonne legacy documenti"
```

- [ ] **Step 10.6: Post-deploy (promemoria per produzione)**

Dopo il deploy in produzione va eseguito una volta il backfill giacenze:

```bash
docker exec prova-job-<sha> bin/rails magazzino:ricalcola_giacenze
```

---

## Rischi e note per l'esecutore

- **after_commit nei test**: i trigger giacenza usano `after_*_commit`; Rails li esegue anche nei test transazionali (comportamento standard da Rails 5). Se un test dei trigger non vede il ricalcolo, verifica di non essere dentro una `transaction` esplicita del test.
- **Fixture ≠ callback**: le fixture inseriscono raw (nessun trigger). I test di Giacenza chiamano sempre `ricalcola` esplicitamente o creano i record via modello.
- **Performance liste documenti**: `consegnato?`/`pagato?` ora costano 1-2 query per documento (prima: `includes(:consegna)`). Con liste paginate da ~30 righe è accettabile (~2.200 documenti totali). Se una lista degrada, memoizzare o precalcolare è un follow-up, non parte di questo piano.
- **`ricalcola_tutte!` non azzera i libri spariti**: la bulk INSERT copre solo libri con movimenti. I trigger per-libro coprono il caso "ultimo movimento cancellato" (ricalcolo a zero). Dopo un import bulk con cancellazioni massicce, rilanciare `magazzino:ricalcola_giacenze` è la recovery.
- **MCP `documenti_stato`**: usa solo l'API dei concern (`mark_*`/`unmark_*`), nessuna modifica necessaria; dopo il Task 5 `unmark_pagato` toglie l'**ultimo** acconto (comportamento nuovo ma coerente).
