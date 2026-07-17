# Adozioni Comunicate dagli Editori — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Import delle adozioni comunicate dagli editori (Excel via web UI, PDF via tool MCP) con matching contro le proprie Adozioni/Classi e write-back del numero alunni su `classi.numero_alunni`.

**Architecture:** Nuovo modello `Adozioni::Comunicata` (tabella `adozioni_comunicate` ricreata: UUID, account_id) + POROs `Adozioni::Comunicate::Importer` (core condiviso) e `Adozioni::Comunicate::Matcher`. Due porte: `Imports::AdozioniComunicateProcessor` nel sistema imports unificato (Excel) e tool MCP `adozioni_comunicate_import` (righe strutturate estratte dal LLM dai PDF). UI di confronto in `adozioni/comunicate#index`.

**Tech Stack:** Rails 8.1, PostgreSQL, Roo (Excel), gem `mcp`, Minitest + fixtures.

**Design di riferimento:** `docs/plans/2026-07-17-adozioni-comunicate-design.md`

---

## Note operative (leggere prima)

- **Tutti i comandi Rails girano nel container**: `docker exec prova-app-1 bin/rails ...` (senza `-it`).
- **Commit**: mai `git add -A` — elencare i file espliciti. Messaggio in Conventional Commits, chiudere con `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- **TDD**: test prima, verificare che fallisca, implementare, verificare che passi.
- **Deviazione dal design doc**: la colonna `classe` è stata rinominata `anno_corso` — `belongs_to :classe` (associazione verso il modello `Classe`) confliggerebbe con un attributo `classe`. `anno_corso` è anche coerente con `Adozione.anno_corso` e `Classe.anno_corso`.
- Se `Adozione.create!`/`Classe.create!` nei test falliscono per validazioni non previste dal piano, leggere il modello e aggiustare i dati di setup, non le validazioni.
- Convenzione select nelle view: sempre `class: "input input--select"`.

---

### Task 1: Migrazione — ricrea `adozioni_comunicate`, elimina vecchio modello

**Files:**
- Create: `db/migrate/20260717090000_ricrea_adozioni_comunicate.rb`
- Delete: `app/models/adozione_comunicata.rb`

**Step 1: Scrivi la migrazione**

```ruby
class RicreaAdozioniComunicate < ActiveRecord::Migration[8.1]
  # La tabella 2025/26 (bigint, user_id, matching su id MIUR volatili) era il
  # controllo dell'anno scorso, ormai consumato: si riparte dalle convenzioni
  # correnti (uuid, account_id, no FK) e dal matching su Adozione/Classe propri.
  def up
    drop_table :adozioni_comunicate

    create_table :adozioni_comunicate, id: :uuid do |t|
      t.uuid    :account_id, null: false
      t.string  :anno_scolastico, null: false
      t.string  :editore
      t.string  :fonte, null: false, default: "excel"
      t.uuid    :import_record_id

      t.string  :codicescuola, null: false
      t.string  :ean, null: false
      t.string  :titolo
      t.string  :anno_corso, null: false
      t.string  :sezioni, null: false, default: ""
      t.integer :alunni, null: false

      t.uuid    :adozione_id
      t.uuid    :classe_id
      t.string  :stato_match, null: false, default: "da_verificare"

      t.string  :descrizione_scuola
      t.string  :comune
      t.string  :provincia

      t.timestamps
    end

    add_index :adozioni_comunicate,
              %i[account_id anno_scolastico codicescuola ean anno_corso sezioni],
              unique: true, name: "index_adozioni_comunicate_unicita"
    add_index :adozioni_comunicate, %i[account_id stato_match]
    add_index :adozioni_comunicate, :adozione_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
```

**Step 2: Elimina il vecchio modello**

```bash
rm app/models/adozione_comunicata.rb
```

(Unico riferimento residuo è un commento in `app/models/import_adozione.rb:28` — aggiornarlo togliendo la menzione di AdozioneComunicata.)

**Step 3: Migra**

Run: `docker exec prova-app-1 bin/rails db:migrate`
Expected: migrazione OK, `annotaterb` gira in automatico o lanciarlo: `docker exec prova-app-1 bundle exec annotaterb models`

**Step 4: Commit**

```bash
git add db/migrate/20260717090000_ricrea_adozioni_comunicate.rb db/schema.rb app/models/import_adozione.rb
git rm app/models/adozione_comunicata.rb
git commit -m "feat(adozioni-comunicate): ricrea tabella con uuid/account, drop modello 2025/26"
```

---

### Task 2: Modello `Adozioni::Comunicata`

**Files:**
- Create: `app/models/adozioni/comunicata.rb`
- Test: `test/models/adozioni/comunicata_test.rb`

**Step 1: Test fallente**

```ruby
require "test_helper"

class Adozioni::ComunicataTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    Current.account = @account
  end

  teardown { Current.reset }

  def valid_attrs(overrides = {})
    { account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9788809917583", anno_corso: "3", sezioni: "B", alunni: 25,
      fonte: "excel" }.merge(overrides)
  end

  test "valida con attributi completi" do
    assert Adozioni::Comunicata.new(valid_attrs).valid?
  end

  test "richiede alunni positivo" do
    refute Adozioni::Comunicata.new(valid_attrs(alunni: 0)).valid?
  end

  test "rifiuta stato_match sconosciuto" do
    refute Adozioni::Comunicata.new(valid_attrs(stato_match: "boh")).valid?
  end

  test "unicita su chiave canonica" do
    Adozioni::Comunicata.create!(valid_attrs)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Adozioni::Comunicata.new(valid_attrs(alunni: 99)).save(validate: false)
    end
  end

  test "normalizza_ean toglie trattini e spazi" do
    assert_equal "9788809917583", Adozioni::Comunicata.normalizza_ean("978-88-0991758 3")
  end

  test "sezioni_lista e multi_sezione?" do
    riga = Adozioni::Comunicata.new(valid_attrs(sezioni: "A, B,C"))
    assert_equal %w[A B C], riga.sezioni_lista
    assert riga.multi_sezione?
    refute Adozioni::Comunicata.new(valid_attrs(sezioni: "A")).multi_sezione?
  end
end
```

**Step 2: Verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicata_test.rb`
Expected: FAIL — `NameError: uninitialized constant Adozioni::Comunicata`

**Step 3: Implementa il modello**

```ruby
module Adozioni
  class Comunicata < ApplicationRecord
    self.table_name = "adozioni_comunicate"

    include AccountScoped

    STATI_MATCH = %w[
      da_verificare matched adozione_non_trovata classe_non_trovata
      multi_sezione multi_sezione_distribuita
    ].freeze

    belongs_to :adozione, optional: true
    belongs_to :classe, optional: true
    belongs_to :import_record, optional: true

    validates :anno_scolastico, :codicescuola, :ean, :anno_corso, presence: true
    validates :alunni, presence: true, numericality: { greater_than: 0 }
    validates :stato_match, inclusion: { in: STATI_MATCH }

    scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
    scope :matched, -> { where(stato_match: %w[matched multi_sezione_distribuita]) }
    scope :discrepanze, -> { where(stato_match: %w[adozione_non_trovata classe_non_trovata multi_sezione]) }
    scope :per_editore, ->(editore) { where(editore: editore) }

    def self.normalizza_ean(raw)
      raw.to_s.gsub(/[^0-9Xx]/, "").upcase
    end

    def sezioni_lista
      sezioni.to_s.split(",").map(&:strip).reject(&:blank?)
    end

    def multi_sezione?
      sezioni_lista.size > 1
    end
  end
end
```

**Step 4: Verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicata_test.rb`
Expected: PASS (6 test)

**Step 5: Commit**

```bash
git add app/models/adozioni/comunicata.rb test/models/adozioni/comunicata_test.rb
git commit -m "feat(adozioni-comunicate): modello Adozioni::Comunicata"
```

---

### Task 3: `Adozioni::Comunicate::Matcher`

**Files:**
- Create: `app/models/adozioni/comunicate/matcher.rb`
- Test: `test/models/adozioni/comunicate/matcher_test.rb`

**Step 1: Test fallente**

```ruby
require "test_helper"

class Adozioni::Comunicate::MatcherTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = scuole(:scuola_fizzy)
    @scuola.update!(codice_ministeriale: "REEE81001P")
    @classe_3b = crea_classe("3", "B")
    @adozione = Adozione.create!(
      account: @account, classe: @classe_3b, codice_isbn: "9788809917583",
      titolo: "NUOVO VIVA CRESCERE 3", anno_scolastico: "202627",
      codicescuola: "REEE81001P", anno_corso: "3"
    )
  end

  teardown { Current.reset }

  def crea_classe(anno_corso, sezione, numero_alunni: nil)
    Classe.create!(account: @account, scuola: @scuola, anno_corso:, sezione:,
                   combinazione: "", stato: "attiva", anno_scolastico: "202627",
                   numero_alunni:)
  end

  def crea_comunicata(overrides = {})
    Adozioni::Comunicata.create!({
      account: @account, anno_scolastico: "202627", codicescuola: "REEE81001P",
      ean: "9788809917583", anno_corso: "3", sezioni: "B", alunni: 25, fonte: "mcp"
    }.merge(overrides))
  end

  test "matched: aggancia adozione e classe e scrive numero_alunni" do
    riga = crea_comunicata
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "matched", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
    assert_equal @classe_3b, riga.classe
    assert_equal 25, @classe_3b.reload.numero_alunni
  end

  test "matched su altra sezione della stessa scuola" do
    classe_3c = crea_classe("3", "C")
    riga = crea_comunicata(sezioni: "C", alunni: 18)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "matched", riga.reload.stato_match
    assert_equal classe_3c, riga.classe
    assert_equal 18, classe_3c.reload.numero_alunni
  end

  test "classe_non_trovata quando la sezione comunicata non esiste" do
    riga = crea_comunicata(sezioni: "Z")
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "classe_non_trovata", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
    assert_nil riga.classe
  end

  test "adozione_non_trovata quando ean non corrisponde" do
    riga = crea_comunicata(ean: "9791223235485")
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "adozione_non_trovata", riga.reload.stato_match
    assert_nil riga.adozione
  end

  test "multi_sezione_distribuita: divide equamente quando tutte le classi esistono e sono vuote" do
    crea_classe("3", "A")
    crea_classe("3", "C")
    riga = crea_comunicata(sezioni: "A,B,C", alunni: 69)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "multi_sezione_distribuita", riga.reload.stato_match
    assert_equal [23, 23, 23],
      Classe.where(scuola: @scuola, anno_corso: "3").order(:sezione).pluck(:numero_alunni)
  end

  test "multi_sezione resta da rivedere se una classe ha gia numero_alunni" do
    crea_classe("3", "A", numero_alunni: 20)
    riga = crea_comunicata(sezioni: "A,B", alunni: 45)
    Adozioni::Comunicate::Matcher.new(riga).match!

    assert_equal "multi_sezione", riga.reload.stato_match
    assert_equal @adozione, riga.adozione
  end

  test "distribuisci! forza la distribuzione sovrascrivendo" do
    crea_classe("3", "A", numero_alunni: 20)
    riga = crea_comunicata(sezioni: "A,B", alunni: 45)
    Adozioni::Comunicate::Matcher.new(riga).match!
    assert Adozioni::Comunicate::Matcher.new(riga.reload).distribuisci!

    assert_equal "multi_sezione_distribuita", riga.reload.stato_match
    assert_equal [23, 22],
      Classe.where(scuola: @scuola, anno_corso: "3", sezione: %w[A B]).order(:sezione).pluck(:numero_alunni)
  end

  test "rimatch! riesegue il matching su tutte le righe dell'anno" do
    riga = crea_comunicata(sezioni: "D")
    Adozioni::Comunicate::Matcher.new(riga).match!
    assert_equal "classe_non_trovata", riga.reload.stato_match

    crea_classe("3", "D")
    Adozioni::Comunicate::Matcher.rimatch!(account: @account, anno_scolastico: "202627")
    assert_equal "matched", riga.reload.stato_match
  end
end
```

**Step 2: Verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicate/matcher_test.rb`
Expected: FAIL — `uninitialized constant Adozioni::Comunicate`

**Step 3: Implementa**

```ruby
module Adozioni
  module Comunicate
    class Matcher
      def self.rimatch!(account:, anno_scolastico:)
        Comunicata.for_account(account).per_anno(anno_scolastico).find_each do |comunicata|
          new(comunicata).match!
        end
      end

      def initialize(comunicata)
        @comunicata = comunicata
      end

      def match!
        adozione = trova_adozione

        if adozione.nil?
          @comunicata.update!(stato_match: "adozione_non_trovata", adozione: nil, classe: nil)
        elsif @comunicata.multi_sezione?
          match_multi_sezione(adozione)
        else
          match_mono_sezione(adozione)
        end
      end

      # Distribuzione forzata dalla UI: sovrascrive numero_alunni esistenti.
      def distribuisci!
        adozione = @comunicata.adozione || trova_adozione
        return false unless adozione

        classi = @comunicata.sezioni_lista.map { |sezione| trova_classe(adozione, sezione) }
        return false unless classi.all?

        distribuisci_su(classi)
        @comunicata.update!(stato_match: "multi_sezione_distribuita", adozione: adozione)
        true
      end

      private

      def trova_adozione
        Adozione.where(
          account_id: @comunicata.account_id,
          anno_scolastico: @comunicata.anno_scolastico,
          codicescuola: @comunicata.codicescuola,
          codice_isbn: @comunicata.ean,
          anno_corso: @comunicata.anno_corso
        ).first
      end

      def match_mono_sezione(adozione)
        classe = trova_classe(adozione, @comunicata.sezioni_lista.first)

        if classe
          @comunicata.update!(stato_match: "matched", adozione: adozione, classe: classe)
          classe.update!(numero_alunni: @comunicata.alunni)
        else
          @comunicata.update!(stato_match: "classe_non_trovata", adozione: adozione, classe: nil)
        end
      end

      def match_multi_sezione(adozione)
        classi = @comunicata.sezioni_lista.map { |sezione| trova_classe(adozione, sezione) }

        if classi.all? && classi.none? { |classe| classe.numero_alunni.present? }
          distribuisci_su(classi)
          @comunicata.update!(stato_match: "multi_sezione_distribuita", adozione: adozione, classe: nil)
        else
          @comunicata.update!(stato_match: "multi_sezione", adozione: adozione, classe: nil)
        end
      end

      def trova_classe(adozione, sezione)
        return nil if sezione.blank?

        if adozione.classe.sezione == sezione && adozione.classe.anno_corso == @comunicata.anno_corso
          return adozione.classe
        end

        Classe.attive.find_by(
          scuola_id: adozione.classe.scuola_id,
          anno_corso: @comunicata.anno_corso,
          sezione: sezione
        )
      end

      def distribuisci_su(classi)
        base, resto = @comunicata.alunni.divmod(classi.size)
        classi.each_with_index do |classe, indice|
          classe.update!(numero_alunni: base + (indice < resto ? 1 : 0))
        end
      end
    end
  end
end
```

**Step 4: Verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicate/matcher_test.rb`
Expected: PASS (8 test)

**Step 5: Commit**

```bash
git add app/models/adozioni/comunicate/matcher.rb test/models/adozioni/comunicate/matcher_test.rb
git commit -m "feat(adozioni-comunicate): Matcher con write-back numero_alunni e distribuzione multi-sezione"
```

---

### Task 4: `Adozioni::Comunicate::Importer` (core condiviso)

**Files:**
- Create: `app/models/adozioni/comunicate/importer.rb`
- Test: `test/models/adozioni/comunicate/importer_test.rb`

**Step 1: Test fallente**

```ruby
require "test_helper"

class Adozioni::Comunicate::ImporterTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = scuole(:scuola_fizzy)
    @scuola.update!(codice_ministeriale: "REEE81001P")
    @classe = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                             sezione: "B", combinazione: "", stato: "attiva",
                             anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: @classe, codice_isbn: "9788809917583",
                     anno_scolastico: "202627", codicescuola: "REEE81001P", anno_corso: "3")
  end

  teardown { Current.reset }

  def importer(fonte: "mcp")
    Adozioni::Comunicate::Importer.new(account: @account, anno_scolastico: "202627",
                                       fonte: fonte, editore: "GIUNTI SCUOLA")
  end

  test "crea la riga, normalizza ean e lancia il matching" do
    importer.import_rows([{ codicescuola: "reee81001p", ean: "978-88-0991-7583",
                            classe: "3", sezioni: "B", alunni: 25, titolo: "VIVA CRESCERE" }])

    riga = Adozioni::Comunicata.sole
    assert_equal "REEE81001P", riga.codicescuola
    assert_equal "9788809917583", riga.ean
    assert_equal "matched", riga.stato_match
    assert_equal "GIUNTI SCUOLA", riga.editore
    assert_equal 25, @classe.reload.numero_alunni
  end

  test "idempotente: reimport aggiorna alunni senza duplicare" do
    2.times do |i|
      importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                              classe: "3", sezioni: "B", alunni: 20 + i }])
    end

    assert_equal 1, Adozioni::Comunicata.count
    assert_equal 21, Adozioni::Comunicata.sole.alunni
  end

  test "accetta campo combinato classi_sezioni" do
    importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                            classi_sezioni: "3B", alunni: 25 }])

    riga = Adozioni::Comunicata.sole
    assert_equal "3", riga.anno_corso
    assert_equal "B", riga.sezioni
  end

  test "classe numerica da Roo (3.0) diventa stringa 3" do
    importer.import_rows([{ codicescuola: "REEE81001P", ean: "9788809917583",
                            classe: 3.0, sezioni: "B", alunni: 25 }])
    assert_equal "3", Adozioni::Comunicata.sole.anno_corso
  end

  test "riga invalida finisce negli errori senza bloccare le altre" do
    result = importer.import_rows([
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "", sezioni: "B", alunni: 25 },
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "3", sezioni: "B", alunni: 25 }
    ])

    assert_equal 1, result.errori.size
    assert_equal 1, result.importate
  end

  test "riepilogo conta matched e discrepanze" do
    result = importer.import_rows([
      { codicescuola: "REEE81001P", ean: "9788809917583", classe: "3", sezioni: "B", alunni: 25 },
      { codicescuola: "REEE81001P", ean: "9791223235485", classe: "4", sezioni: "A", alunni: 10 }
    ])

    riepilogo = result.riepilogo
    assert_equal 2, riepilogo[:importate]
    assert_equal 1, riepilogo[:matched]
    assert_equal 1, riepilogo[:discrepanze].size
    assert_equal "adozione_non_trovata", riepilogo[:discrepanze].first[:stato_match]
  end
end
```

**Step 2: Verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicate/importer_test.rb`
Expected: FAIL — `uninitialized constant ... Importer`

**Step 3: Implementa**

```ruby
module Adozioni
  module Comunicate
    class Importer
      attr_reader :importate, :aggiornate, :errori

      def initialize(account:, anno_scolastico:, fonte:, editore: nil, import_record_id: nil)
        @account = account
        @anno_scolastico = anno_scolastico.to_s
        @fonte = fonte
        @editore = editore
        @import_record_id = import_record_id
        @importate = 0
        @aggiornate = 0
        @errori = []
        @record_ids = []
      end

      def import_rows(rows)
        rows.each_with_index do |row, indice|
          import_row(row.to_h.symbolize_keys)
        rescue ActiveRecord::RecordInvalid, ArgumentError, KeyError => e
          @errori << "Riga #{indice + 1}: #{e.message}"
        end
        self
      end

      def import_row(attrs)
        anno_corso, sezioni = estrai_anno_corso_e_sezioni(attrs)

        comunicata = Comunicata.where(
          account: @account,
          anno_scolastico: @anno_scolastico,
          codicescuola: attrs.fetch(:codicescuola).to_s.strip.upcase,
          ean: Comunicata.normalizza_ean(attrs.fetch(:ean)),
          anno_corso: anno_corso,
          sezioni: sezioni
        ).first_or_initialize

        nuova = comunicata.new_record?
        comunicata.assign_attributes(
          alunni: attrs.fetch(:alunni).to_i,
          fonte: @fonte,
          import_record_id: @import_record_id || comunicata.import_record_id,
          titolo: attrs[:titolo].presence || comunicata.titolo,
          editore: attrs[:editore].presence || @editore || comunicata.editore,
          descrizione_scuola: attrs[:descrizione_scuola].presence || comunicata.descrizione_scuola,
          comune: attrs[:comune].presence || comunicata.comune,
          provincia: attrs[:provincia].presence || comunicata.provincia
        )
        comunicata.save!
        Matcher.new(comunicata).match!

        nuova ? @importate += 1 : @aggiornate += 1
        @record_ids << comunicata.id
        comunicata
      end

      def riepilogo
        righe = Comunicata.where(id: @record_ids)
        {
          importate: @importate,
          aggiornate: @aggiornate,
          errori: @errori,
          matched: righe.matched.count,
          discrepanze: righe.discrepanze.map do |riga|
            riga.slice(:codicescuola, :descrizione_scuola, :ean, :titolo,
                       :anno_corso, :sezioni, :alunni, :stato_match).symbolize_keys
          end
        }
      end

      private

      # Accetta classe/sezione separati (chiavi :classe o :anno_corso, :sezione o
      # :sezioni) oppure il campo combinato :classi_sezioni ("3B", "3 B", "3/B").
      def estrai_anno_corso_e_sezioni(attrs)
        anno_corso = attrs[:classe].presence || attrs[:anno_corso]
        sezioni = attrs[:sezioni].presence || attrs[:sezione]

        if anno_corso.blank? && attrs[:classi_sezioni].present?
          anno_corso, sezioni = split_classi_sezioni(attrs[:classi_sezioni])
        end

        anno_corso = anno_corso.is_a?(Numeric) ? anno_corso.to_i.to_s : anno_corso.to_s.strip
        raise ArgumentError, "classe/anno corso mancante" if anno_corso.blank?

        sezioni = sezioni.to_s.split(",").map { |s| s.strip.upcase }.reject(&:empty?).join(",")
        [anno_corso, sezioni]
      end

      def split_classi_sezioni(value)
        match = value.to_s.strip.match(%r{\A(\d)\s*[-/_ ]*\s*([A-Za-z].*)\z})
        match ? [match[1], match[2]] : [value.to_s.strip, ""]
      end
    end
  end
end
```

**Step 4: Verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/models/adozioni/comunicate/importer_test.rb`
Expected: PASS (6 test)

**Step 5: Commit**

```bash
git add app/models/adozioni/comunicate/importer.rb test/models/adozioni/comunicate/importer_test.rb
git commit -m "feat(adozioni-comunicate): Importer condiviso idempotente con riepilogo discrepanze"
```

---

### Task 5: Excel — enum ImportRecord + `Imports::AdozioniComunicateProcessor`

**Files:**
- Modify: `app/models/import_record.rb:36-43` (enum) e `:60` (passa id nel metadata)
- Create: `app/services/imports/adozioni_comunicate_processor.rb`
- Test: `test/services/imports/adozioni_comunicate_processor_test.rb`

Nota: `app/services` è legacy ma il dispatch `ImportRecord#processor_class` costruisce `Imports::#{import_type.camelize}Processor` e tutta la famiglia vive lì — il processor è un adapter sottile, la logica sta in `app/models/adozioni/`.

**Step 1: Test fallente** (genera l'xlsx col gem caxlsx già in bundle)

```ruby
require "test_helper"

class Imports::AdozioniComunicateProcessorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    Current.account = @account
    @scuola = scuole(:scuola_fizzy)
    @scuola.update!(codice_ministeriale: "REEE81001P")
    classe = Classe.create!(account: @account, scuola: @scuola, anno_corso: "3",
                            sezione: "B", combinazione: "", stato: "attiva",
                            anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: classe, codice_isbn: "9788809917583",
                     anno_scolastico: "202627", codicescuola: "REEE81001P", anno_corso: "3")
  end

  teardown { Current.reset }

  test "importa il tracciato Giunti e matcha" do
    path = crea_xlsx([
      ["011302200T", "202627", "REEE81001P", "S. PROSPERO", "VIA ALLENDE 3", "42100",
       "REGGIO NELL'EMILIA", "RE", "A0650", "E0650", "9788809917583",
       "NUOVO VIVA CRESCERE CL. 3", "3", "B", "25"]
    ])

    processor = Imports::AdozioniComunicateProcessor.new(
      path, nil, metadata: { "anno_scolastico" => "202627" }, account: @account
    ).call

    assert processor.success?, processor.errors.inspect
    assert_equal 1, processor.imported_count
    assert_equal "matched", Adozioni::Comunicata.sole.stato_match
  end

  private

  HEADER = ["Cod. Agente", "Anno", "CodMinisteriale", "Descrizione", "Indirizzo", "CAP",
            "Comune", "Provincia", "Cod. Sc.", "Editore", "Ean", "Titolo",
            "Classe", "Sezione", "Alunni"].freeze

  def crea_xlsx(rows)
    require "caxlsx"
    path = Rails.root.join("tmp", "test_adozioni_comunicate.xlsx").to_s
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Foglio1") do |sheet|
      sheet.add_row HEADER
      rows.each { |row| sheet.add_row row }
    end
    package.serialize(path)
    path
  end
end
```

**Step 2: Verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/services/imports/adozioni_comunicate_processor_test.rb`
Expected: FAIL — `uninitialized constant Imports::AdozioniComunicateProcessor`

**Step 3: Implementa**

In `app/models/import_record.rb` aggiungi all'enum:

```ruby
  enum :import_type, {
    libri: 0,
    clienti: 1,
    documenti: 2,
    confezioni: 3,
    ministeriali: 4,
    insegnanti: 5,
    adozioni_comunicate: 6
  }
```

Sempre in `import_record.rb`, in `process!` passa l'id del record nel metadata (serve per la tracciabilità delle righe; gli altri processor leggono solo le proprie chiavi, non cambia nulla per loro):

```ruby
    result = processor_class.new(
      file, user,
      metadata: (metadata&.stringify_keys || {}).merge("import_record_id" => id),
      account: account
    ).call
```

`app/services/imports/adozioni_comunicate_processor.rb`:

```ruby
# frozen_string_literal: true

module Imports
  class AdozioniComunicateProcessor < BaseProcessor
    def process_file
      importer = nil

      parse_excel do |row, line|
        importer ||= build_importer(row)
        importer.import_row(
          codicescuola: row[:codministeriale],
          ean: row[:ean],
          titolo: row[:titolo],
          classe: row[:classe],
          sezione: row[:sezione],
          classi_sezioni: row[:"classi+sezioni"],
          alunni: row[:alunni],
          editore: row[:editore],
          descrizione_scuola: row[:descrizione],
          comune: row[:comune],
          provincia: row[:provincia]
        )
      rescue ActiveRecord::RecordInvalid, ArgumentError, KeyError => e
        add_error(e.message, line: line)
      end

      @imported_count = importer&.importate.to_i
      @updated_count = importer&.aggiornate.to_i
    end

    private

    def build_importer(row)
      anno = @metadata["anno_scolastico"].presence || row[:anno].to_s.presence
      raise ArgumentError, "anno scolastico mancante (colonna Anno o metadata)" if anno.blank?

      ::Adozioni::Comunicate::Importer.new(
        account: @account,
        anno_scolastico: anno,
        fonte: "excel",
        import_record_id: @metadata["import_record_id"]
      )
    end
  end
end
```

**Step 4: Verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/services/imports/adozioni_comunicate_processor_test.rb`
Expected: PASS

**Step 5: Regressione sugli import esistenti**

Run: `docker exec prova-app-1 bin/rails test test/models/import_record_test.rb test/services/ test/controllers/imports_controller_test.rb 2>/dev/null` (lancia quelli che esistono)
Expected: PASS

**Step 6: Commit**

```bash
git add app/models/import_record.rb app/services/imports/adozioni_comunicate_processor.rb test/services/imports/adozioni_comunicate_processor_test.rb
git commit -m "feat(adozioni-comunicate): import Excel via sistema imports unificato"
```

---

### Task 6: Web UI dell'import (form in `imports/new`)

**Files:**
- Modify: `app/views/imports/new.html.erb:17` (aggiungi il tipo)
- Modify: `app/helpers/imports_helper.rb` (icona/label)
- Create: `app/views/imports/forms/_adozioni_comunicate_form.html.erb`

**Step 1: Aggiungi il tipo alla barra dei tipi** in `imports/new.html.erb`:

```erb
    <% %w[libri clienti documenti adozioni_comunicate].each do |type| %>
```

**Step 2: Helper** — in `imports_helper.rb` aggiungi i rami:

```ruby
    when "adozioni_comunicate" then "clipboard-document-check"   # in import_type_icon
    when "adozioni_comunicate" then "Adozioni editore"           # in import_type_label
    when "adozioni_comunicate" then "txt-feature"                # in import_type_text_class
```

(Se l'icona `clipboard-document-check` non è registrata, usare la skill **icon-agent** per aggiungerla, o ripiegare su `arrow-down-tray`.)

**Step 3: Form partial** `_adozioni_comunicate_form.html.erb` (ricalca la parte semplice di `_libri_form`):

```erb
<%= turbo_frame_tag :import_form do %>
  <article class="panel panel--wide shadow center txt-align-start margin-block-start">
    <%= form_with model: import, url: imports_path, method: :post,
        class: "flex flex-column gap",
        data: { controller: "form upload-preview", turbo_frame: "_top" }, multipart: true do |f| %>
      <%= f.hidden_field :import_type, value: "adozioni_comunicate" %>

      <h2 class="txt-large margin-none font-weight-black">Importa adozioni comunicate dall'editore</h2>

      <p class="txt-subtle margin-none txt-small">
        Excel con una riga per classe/sezione (CodMinisteriale, Ean, Classe, Sezione, Alunni).
        Le righe vengono confrontate con le tue adozioni e il numero alunni aggiorna le classi.
        Per i PDF usa il tool MCP <code>adozioni_comunicate_import</code> da Claude/GPT.
      </p>

      <label class="flex flex-column gap-half">
        <span class="txt-small font-weight-bold">Anno scolastico</span>
        <%= select_tag "import_record[metadata][anno_scolastico]",
            options_for_select([["2026/27", "202627"], ["2027/28", "202728"]], "202627"),
            class: "input input--select" %>
      </label>

      <label class="btn input--upload">
        <div data-upload-preview-target="placeholder">Scegli un file Excel...</div>
        <div data-upload-preview-target="fileName" hidden></div>
        <%= f.file_field :file,
            accept: ".xlsx,.xls",
            required: true,
            data: { action: "upload-preview#previewFileName", upload_preview_target: "input" } %>
      </label>

      <%= f.button type: :submit, class: "btn btn--link center" do %>
        <span>Importa adozioni</span>
      <% end %>
    <% end %>
  </article>

  <article class="panel panel--wide center txt-align-start margin-block-start">
    <%= link_to adozioni_comunicate_path, class: "btn" do %>
      <span>Vai al confronto adozioni comunicate</span>
    <% end %>
  </article>
<% end %>
```

(Il link `adozioni_comunicate_path` arriva col Task 8 — se si esegue questo task prima, commentarlo e scommentarlo al Task 8.)

**Step 4: Verifica a mano**

Indicare a Paolo l'URL: `http://localhost:3000/<account>/imports/new?type=adozioni_comunicate` — controllare che il form appaia e che l'upload di `/home/paolotax/Downloads/Adozioni 202627 (2).xlsx` completi (pagina show dell'import con conteggi).

**Step 5: Commit**

```bash
git add app/views/imports/new.html.erb app/helpers/imports_helper.rb app/views/imports/forms/_adozioni_comunicate_form.html.erb
git commit -m "feat(adozioni-comunicate): form upload Excel in importazioni"
```

---

### Task 7: Tool MCP `adozioni_comunicate_import`

**Files:**
- Create: `app/tools/mcp_tools/adozioni_comunicate_import.rb`
- Test: `test/tools/adozioni_comunicate_import_test.rb` (se esiste già `test/tools/`, seguirne le convenzioni; altrimenti crearlo)

**Step 1: Test fallente**

```ruby
require "test_helper"

class AdozioniComunicateImportToolTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:fizzy)
    @user = @account.users.first
    scuola = scuole(:scuola_fizzy)
    scuola.update!(codice_ministeriale: "REEE81001P")
    Current.account = @account
    classe = Classe.create!(account: @account, scuola: scuola, anno_corso: "5",
                            sezione: "A", combinazione: "", stato: "attiva",
                            anno_scolastico: "202627")
    Adozione.create!(account: @account, classe: classe, codice_isbn: "9788883886201",
                     anno_scolastico: "202627", codicescuola: "REEE81001P", anno_corso: "5")
    Current.reset
  end

  teardown { Current.reset }

  test "importa righe strutturate e risponde col riepilogo" do
    response = MCPTools::AdozioniComunicateImport.call(
      anno_scolastico: "202627",
      editore: "TREDIECI",
      righe: [
        { "codicescuola" => "REEE81001P", "ean" => "9788883886201",
          "titolo" => "LEGGO CON TE 5", "classe" => "5", "sezioni" => "A", "alunni" => 13 },
        { "codicescuola" => "REEE99999X", "ean" => "9788883886195",
          "classe" => "4", "sezioni" => "A", "alunni" => 23 }
      ],
      server_context: { user: @user, account: @account }
    )

    payload = JSON.parse(response.content.first[:text])
    assert_equal 2, payload["importate"]
    assert_equal 1, payload["matched"]
    assert_equal 1, payload["discrepanze"].size
    assert_equal "adozione_non_trovata", payload["discrepanze"].first["stato_match"]
  end
end
```

**Step 2: Verifica che fallisca**

Run: `docker exec prova-app-1 bin/rails test test/tools/adozioni_comunicate_import_test.rb`
Expected: FAIL — `uninitialized constant MCPTools::AdozioniComunicateImport`

**Step 3: Implementa**

```ruby
module MCPTools
  class AdozioniComunicateImport < Base
    tool_name "adozioni_comunicate_import"
    description "Importa le adozioni comunicate da un editore (numero alunni per " \
                "classe/sezione) e le confronta con le adozioni esistenti, aggiornando " \
                "il numero alunni delle classi corrispondenti. Usare dopo aver estratto " \
                "le righe da un PDF o Excel dell'editore. Idempotente: rilanciare " \
                "aggiorna gli alunni senza duplicare. Risponde con riepilogo e discrepanze."

    annotations(
      read_only_hint: false,
      destructive_hint: false,
      idempotent_hint: true
    )

    input_schema(
      type: "object",
      required: %w[anno_scolastico righe],
      properties: {
        anno_scolastico: { type: "string", description: "Es. '202627' per il 2026/27" },
        editore: { type: "string", description: "Editore mittente, usato per le righe senza editore" },
        righe: {
          type: "array",
          description: "Una riga per classe/sezione. Se il documento raggruppa le sezioni (es. '5 A,B,C - 69 alunni totali') NON dividere: passare sezioni='A,B,C' e alunni=69.",
          items: {
            type: "object",
            required: %w[codicescuola ean classe alunni],
            properties: {
              codicescuola: { type: "string", description: "Codice meccanografico del plesso (es. REEE81001P)" },
              ean: { type: "string", description: "EAN/ISBN13, trattini e spazi ammessi" },
              titolo: { type: "string" },
              classe: { type: "string", description: "Anno di corso: 1..5" },
              sezioni: { type: "string", description: "'A' oppure 'A,B,C' se raggruppate (alunni = totale)" },
              alunni: { type: "integer", description: "Numero alunni (totale della riga)" },
              editore: { type: "string" },
              descrizione_scuola: { type: "string" },
              comune: { type: "string" },
              provincia: { type: "string" }
            }
          }
        }
      }
    )

    def self.call(anno_scolastico:, righe:, editore: nil, server_context:, **_params)
      with_current(server_context) do
        importer = ::Adozioni::Comunicate::Importer.new(
          account: account(server_context),
          anno_scolastico: anno_scolastico,
          fonte: "mcp",
          editore: editore
        )
        importer.import_rows(righe)

        MCP::Tool::Response.new([{ type: "text", text: importer.riepilogo.to_json }])
      rescue ActiveRecord::RecordInvalid, ArgumentError => e
        MCP::Tool::Response.new([{ type: "text", text: { error: e.message }.to_json }], error: true)
      end
    end
  end
end
```

**Step 4: Verifica che passi**

Run: `docker exec prova-app-1 bin/rails test test/tools/adozioni_comunicate_import_test.rb`
Expected: PASS

Il tool si registra da solo (glob `app/tools/mcp_tools/*.rb` in `McpController#load_mcp_tools!`).

**Step 5: Commit**

```bash
git add app/tools/mcp_tools/adozioni_comunicate_import.rb test/tools/adozioni_comunicate_import_test.rb
git commit -m "feat(adozioni-comunicate): tool MCP adozioni_comunicate_import per PDF via LLM"
```

---

### Task 8: UI di confronto (`adozioni/comunicate#index`)

**Files:**
- Modify: `config/routes.rb` (vicino a `controllo_adozioni`, ~riga 379)
- Create: `app/controllers/adozioni/comunicate_controller.rb`
- Create: `app/controllers/adozioni/rimatches_controller.rb`
- Create: `app/controllers/adozioni/distribuzioni_controller.rb`
- Create: `app/views/adozioni/comunicate/index.html.erb`
- Test: `test/controllers/adozioni/comunicate_controller_test.rb`

**Step 1: Route** (nomi espliciti, come `controllo_adozioni`, per non dipendere dall'inflector):

```ruby
    get  "adozioni_comunicate", to: "adozioni/comunicate#index", as: :adozioni_comunicate
    post "adozioni_comunicate/rimatch", to: "adozioni/rimatches#create", as: :adozioni_comunicate_rimatch
    post "adozioni_comunicate/:id/distribuzione", to: "adozioni/distribuzioni#create", as: :adozioni_comunicata_distribuzione
```

**Step 2: Test fallente** (per l'auth nel setup copiare il pattern di un controller test esistente, es. quello di `controllo_adozioni` o `giacenze`):

```ruby
require "test_helper"

class Adozioni::ComunicateControllerTest < ActionDispatch::IntegrationTest
  # setup: copiare il sign-in helper usato dagli altri controller test del progetto
  # (Devise: sign_in users(:...) + account nel path)

  test "index mostra le righe e il riepilogo" do
    get adozioni_comunicate_path(script_name: "/#{account.slug}")   # adattare al pattern del progetto
    assert_response :success
  end

  test "rimatch rilancia il matching e redirige" do
    post adozioni_comunicate_rimatch_path(anno_scolastico: "202627")
    assert_redirected_to adozioni_comunicate_path
  end
end
```

Adattare i path al pattern reale degli altri test (guardare come costruiscono gli URL account-scoped) e aggiungere una `Adozioni::Comunicata` di setup come nei task precedenti.

**Step 3: Controller**

`app/controllers/adozioni/comunicate_controller.rb`:

```ruby
module Adozioni
  class ComunicateController < ApplicationController
    def index
      @anno_scolastico = params[:anno_scolastico].presence ||
                         scope_base.maximum(:anno_scolastico) ||
                         "202627"

      @comunicate = scope_base.per_anno(@anno_scolastico)
      @editori = @comunicate.distinct.order(:editore).pluck(:editore).compact

      @comunicate = @comunicate.per_editore(params[:editore]) if params[:editore].present?
      @comunicate = @comunicate.where(stato_match: params[:stato_match]) if params[:stato_match].present?
      @comunicate = @comunicate.order(:provincia, :comune, :codicescuola, :anno_corso, :sezioni)

      @totale = @comunicate.count
      @matched = @comunicate.matched.count
      @discrepanze = @comunicate.discrepanze.count
    end

    private

    def scope_base
      Comunicata.for_account(Current.account)
    end
  end
end
```

`app/controllers/adozioni/rimatches_controller.rb`:

```ruby
module Adozioni
  class RimatchesController < ApplicationController
    def create
      anno = params[:anno_scolastico].presence || "202627"
      Comunicate::Matcher.rimatch!(account: Current.account, anno_scolastico: anno)
      redirect_to adozioni_comunicate_path(anno_scolastico: anno), notice: "Matching rieseguito"
    end
  end
end
```

`app/controllers/adozioni/distribuzioni_controller.rb`:

```ruby
module Adozioni
  class DistribuzioniController < ApplicationController
    def create
      comunicata = Comunicata.for_account(Current.account).find(params[:id])

      if Comunicate::Matcher.new(comunicata).distribuisci!
        redirect_to adozioni_comunicate_path(anno_scolastico: comunicata.anno_scolastico),
                    notice: "Alunni distribuiti su #{comunicata.sezioni}"
      else
        redirect_to adozioni_comunicate_path(anno_scolastico: comunicata.anno_scolastico),
                    alert: "Impossibile distribuire: classi mancanti per #{comunicata.sezioni}"
      end
    end
  end
end
```

**Step 4: View** `app/views/adozioni/comunicate/index.html.erb` — tabella canonica `.table` (vedi convenzioni in `docs/partials-cards.md` e memoria data-table: scroller orizzontale):

```erb
<% @page_title = "Adozioni comunicate" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= header_back_link account_root_path, label: "Dashboard" %>
  </div>
  <h1 class="header__title"><%= @page_title %> <span class="txt-subtle"><%= @anno_scolastico %></span></h1>
  <div class="header__actions header__actions--end">
    <%= button_to "Ri-esegui matching", adozioni_comunicate_rimatch_path(anno_scolastico: @anno_scolastico), class: "btn" %>
  </div>
<% end %>

<article class="panel panel--wide center txt-align-start">
  <div class="flex align-center gap justify-between flex-wrap">
    <div class="flex gap txt-small">
      <span><strong><%= @totale %></strong> righe</span>
      <span class="txt-positive"><strong><%= @matched %></strong> matched</span>
      <span class="txt-negative"><strong><%= @discrepanze %></strong> discrepanze</span>
    </div>

    <%= form_with url: adozioni_comunicate_path, method: :get, class: "flex gap-half align-center" do %>
      <%= hidden_field_tag :anno_scolastico, @anno_scolastico %>
      <%= select_tag :editore,
          options_for_select([["Tutti gli editori", ""]] + @editori.map { |e| [e, e] }, params[:editore]),
          class: "input input--select", onchange: "this.form.requestSubmit()" %>
      <%= select_tag :stato_match,
          options_for_select([["Tutti gli stati", ""]] + Adozioni::Comunicata::STATI_MATCH.map { |s| [s.humanize, s] }, params[:stato_match]),
          class: "input input--select", onchange: "this.form.requestSubmit()" %>
    <% end %>
  </div>
</article>

<article class="panel panel--wide center txt-align-start margin-block-start">
  <div style="overflow-x: auto;">
    <table class="table">
      <thead>
        <tr>
          <th>Scuola</th>
          <th>EAN / Titolo</th>
          <th>Classe</th>
          <th class="txt-align-end">Alunni</th>
          <th>Editore</th>
          <th>Stato</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <% @comunicate.each do |riga| %>
          <tr>
            <td>
              <div class="font-weight-bold"><%= riga.codicescuola %></div>
              <div class="txt-x-small txt-subtle"><%= [riga.descrizione_scuola, riga.comune].compact.join(" — ") %></div>
            </td>
            <td>
              <div class="txt-small"><%= riga.ean %></div>
              <div class="txt-x-small txt-subtle"><%= riga.titolo %></div>
            </td>
            <td><%= riga.anno_corso %><%= riga.sezioni.presence && " #{riga.sezioni}" %></td>
            <td class="txt-align-end"><%= riga.alunni %></td>
            <td class="txt-small"><%= riga.editore %></td>
            <td>
              <span class="txt-small <%= riga.stato_match.in?(%w[matched multi_sezione_distribuita]) ? 'txt-positive' : 'txt-negative' %>">
                <%= riga.stato_match.humanize %>
              </span>
            </td>
            <td>
              <% if riga.stato_match == "multi_sezione" %>
                <%= button_to "Distribuisci", adozioni_comunicata_distribuzione_path(riga), class: "btn btn--small" %>
              <% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</article>
```

**Step 5: Verifica**

Run: `docker exec prova-app-1 bin/rails test test/controllers/adozioni/comunicate_controller_test.rb`
Expected: PASS

Indicare a Paolo l'URL da verificare nel browser: `/adozioni_comunicate` (dopo un import di prova con l'Excel di Giunti).

**Step 6: Commit**

```bash
git add config/routes.rb app/controllers/adozioni/comunicate_controller.rb app/controllers/adozioni/rimatches_controller.rb app/controllers/adozioni/distribuzioni_controller.rb app/views/adozioni/comunicate/index.html.erb test/controllers/adozioni/comunicate_controller_test.rb
git commit -m "feat(adozioni-comunicate): pagina confronto con filtri, rimatch e distribuzione"
```

---

### Task 9: Suite completa + scagnozz-cli

**Step 1: Suite completa**

Run: `docker exec prova-app-1 bin/rails test`
Expected: PASS, nessuna regressione (attenzione a test esistenti che toccano ImportRecord o le fixtures classi/adozioni usate nei setup).

**Step 2: Annotate**

Run: `docker exec prova-app-1 bundle exec annotaterb models`
Committare eventuali diff di annotazioni sui file toccati.

**Step 3: scagnozz-cli (regola: MCP e CLI sempre in sync)**

Nuovo tool MCP ⇒ aggiornare **scagnozz-cli** (comando Cobra + client MCP) e le **2 copie di SKILL.md**. Leggere `~/.claude/projects/-home-paolotax-rails-2023-prova/memory/project_scagnozz_cli.md` per path e stato del repo Go. Questo è un repo separato: farlo come coda del lavoro, con commit separato lì.

**Step 4: Verifica end-to-end (con Paolo)**

1. Import Excel Giunti da `/imports/new?type=adozioni_comunicate` con `/home/paolotax/Downloads/Adozioni 202627 (2).xlsx`
2. Controllo su `/adozioni_comunicate`: righe, matched, discrepanze, `numero_alunni` sulle classi
3. Da Claude (web/mobile con MCP scagnozz): allegare `/home/paolotax/Downloads/Adozioni TREDIECI Reggio Emilia per scuola.pdf`, chiedere di estrarre le righe e chiamare `adozioni_comunicate_import` con `anno_scolastico: "202627"`, `editore: "TREDIECI"`
4. Verificare le righe multi-sezione TREDIECI (es. "5 A,B,C → 69") e il bottone Distribuisci

---

## Fuori scope (deferred, YAGNI)

- Filtri canonici `Filters::*Filter` + `FilterScoped` + popup (v1 usa select semplici; upgrade quando la pagina si consolida)
- Parsing PDF server-side con ruby_llm
- Export Excel del confronto (c'era nella versione 2025/26, nessuno lo usava)
- Controllo mandato editore (`user.miei_editori`) sul flusso import — da valutare quando si vede quanta spazzatura arriva
