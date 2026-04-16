# Refactoring `GiriController` + `TappeController` — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rendere `GiriController` e `TappeController` "thin": spostare logica nei modelli, estrarre il filtering in `Filters::TappaFilter`, separare azioni non-CRUD in controller dedicati.

**Architecture:** Modelli ricchi (Tappa scopes, Giro presentation methods/callbacks), filter STI persistente (pattern AppuntoFilter/DocumentoFilter), controller CRUD puri, azioni non-CRUD come sub-resource (`Giri::PlannersController`, `Giri::CopieController`, `Tappe::SortsController`, `Tappe::RimandiController`).

**Tech Stack:** Rails 8.1, Minitest, fixtures, Docker (`prova-app-1`), Turbo, Stimulus, ActionCable.

**Branch:** `feature/refactor-giri-tappe`

**Design doc:** `docs/plans/2026-04-16-giri-tappe-controllers-refactoring-design.md`

**Test command (tutti i test):** `docker exec prova-app-1 bin/rails test`
**Test command (file specifico):** `docker exec prova-app-1 bin/rails test test/models/tappa_test.rb`

---

## Task 1: Scope `Tappa.raggruppate_per_area`

Centralizza la logica di grouping per area/direzione ora duplicata in `GiriController#planner_tappe_per_area` (righe 135-156) e `TappeController#planner_tappe_per_area`/`giro_planner_tappe_per_area` (righe 249-282).

**Files:**
- Modify: `app/models/tappa.rb` (aggiunge scope)
- Test: `test/models/tappa_test.rb` (aggiunge 3 test)

**Step 1: Write failing tests**

Aggiungi in `test/models/tappa_test.rb` prima di `end` finale:

```ruby
# Task 2 — Tappa.raggruppate_per_area

test "raggruppate_per_area groups tappe by area and direzione" do
  scuola_a = scuole(:scuola_fizzy)
  scuola_a.update!(area: "Area Nord")
  tappa_a = @user.tappe.create!(tappable: scuola_a, data_tappa: nil)
  tappa_a.tappa_giri.create!(giro: @giro)

  result = @user.tappe.da_programmare.raggruppate_per_area

  assert_equal 1, result.size
  area, direzioni = result.first
  assert_equal "Area Nord", area
  assert_equal 1, direzioni.size
  _direzione, tappe = direzioni.first
  assert_includes tappe, tappa_a
end

test "raggruppate_per_area uses 'Senza area' when scuola area is blank" do
  scuola = scuole(:scuola_fizzy)
  scuola.update!(area: nil)
  tappa = @user.tappe.create!(tappable: scuola, data_tappa: nil)

  result = @user.tappe.da_programmare.raggruppate_per_area

  assert_equal "Senza area", result.first.first
end

test "raggruppate_per_area sorts 'Senza area' last" do
  scuola_a = scuole(:scuola_fizzy)
  scuola_a.update!(area: "Area A")
  scuola_b = Scuola.create!(account: @fizzy, denominazione: "S-B", codice: "B123", area: nil)

  @user.tappe.create!(tappable: scuola_a, data_tappa: nil)
  @user.tappe.create!(tappable: scuola_b, data_tappa: nil)

  aree = @user.tappe.da_programmare.raggruppate_per_area.map(&:first)
  assert_equal ["Area A", "Senza area"], aree
end
```

**Step 2: Run tests — fail**

```
docker exec prova-app-1 bin/rails test test/models/tappa_test.rb -n "/raggruppate_per_area/"
```
Expected: `NoMethodError: undefined method 'raggruppate_per_area'`

**Step 3: Implement scope**

In `app/models/tappa.rb`, dopo lo scope `per_comune_e_direzione`, aggiungi:

```ruby
scope :raggruppate_per_area, -> {
  tappe = where(tappable_type: "Scuola").includes(:giri).preload(:tappable).to_a

  scuole = tappe.map(&:tappable).compact.uniq
  ActiveRecord::Associations::Preloader.new(records: scuole, associations: :direzione).call

  tappe
    .group_by { |t| t.tappable.area.presence || "Senza area" }
    .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
    .map { |area, area_tappe|
      direzioni = area_tappe
        .group_by { |t| t.tappable.direzione || t.tappable }
        .sort_by { |dir, _| dir.denominazione.to_s }
      [area, direzioni]
    }
}
```

**Step 4: Run tests — pass**

```
docker exec prova-app-1 bin/rails test test/models/tappa_test.rb -n "/raggruppate_per_area/"
```
Expected: 3 passing.

**Step 5: Commit**

```bash
git add app/models/tappa.rb test/models/tappa_test.rb
git commit -m "feat(tappa): add raggruppate_per_area scope for planner grouping"
```

---

## Task 2: Scope `Tappa.per_settimana`

Sostituisce il blocco `beginning_of_week + week_offset.weeks` di `TappeController#index:82-86`.

**Files:**
- Modify: `app/models/tappa.rb`
- Test: `test/models/tappa_test.rb`

**Step 1: Write failing tests**

```ruby
# Task 3 — Tappa.per_settimana

test "per_settimana filters tappe within current week by default" do
  monday = Date.current.beginning_of_week
  friday = monday + 4
  in_week = @user.tappe.create!(tappable: @scuola, data_tappa: friday)
  next_week = @user.tappe.create!(tappable: @scuola, data_tappa: monday + 10)

  result = @user.tappe.per_settimana
  assert_includes result, in_week
  assert_not_includes result, next_week
end

test "per_settimana accepts offset in weeks" do
  monday_next = Date.current.beginning_of_week + 1.week
  tappa = @user.tappe.create!(tappable: @scuola, data_tappa: monday_next + 2)

  assert_includes @user.tappe.per_settimana(1), tappa
  assert_not_includes @user.tappe.per_settimana(0), tappa
end
```

**Step 2: Run tests — fail**

```
docker exec prova-app-1 bin/rails test test/models/tappa_test.rb -n "/per_settimana/"
```

**Step 3: Implement scope**

In `app/models/tappa.rb`, dopo `scope :del_mese`, aggiungi:

```ruby
scope :per_settimana, ->(offset = 0) {
  start_of_week = Date.current.beginning_of_week + offset.to_i.weeks
  where(data_tappa: start_of_week..start_of_week.end_of_week)
}
```

**Step 4: Run tests — pass**

**Step 5: Commit**

```bash
git add app/models/tappa.rb test/models/tappa_test.rb
git commit -m "feat(tappa): add per_settimana scope"
```

---

## Task 3: Callback `Giro#set_default_finito_il`

Sposta la logica ora in `GiriController#set_default_finito_il` (righe 107-112) a callback `before_validation` del modello.

**Files:**
- Modify: `app/models/giro.rb`
- Create: `test/models/giro_test.rb` (se non esiste)

**Step 1: Check se esiste il test file**

```
docker exec prova-app-1 ls test/models/giro_test.rb 2>&1
```

Se non esiste, crealo con setup base:

```ruby
require "test_helper"

class GiroTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships

  setup do
    @fizzy = accounts(:fizzy)
    @user  = users(:one)
    Current.account = @fizzy
    Current.user = @user
  end

  teardown { Current.reset }
end
```

**Step 2: Write failing test**

Dentro `class GiroTest`:

```ruby
# Task 3 — set_default_finito_il

test "sets finito_il to iniziato_il + 4 weeks when blank" do
  giro = @user.giri.new(titolo: "G1", iniziato_il: Date.current)
  giro.valid?
  assert_equal Date.current + 4.weeks, giro.finito_il.to_date
end

test "does not override finito_il when already set and >= iniziato_il" do
  iniziato = Date.current
  finito   = iniziato + 1.week
  giro = @user.giri.new(titolo: "G2", iniziato_il: iniziato, finito_il: finito)
  giro.valid?
  assert_equal finito, giro.finito_il.to_date
end

test "resets finito_il when before iniziato_il" do
  iniziato = Date.current
  giro = @user.giri.new(titolo: "G3", iniziato_il: iniziato, finito_il: iniziato - 1.day)
  giro.valid?
  assert_equal iniziato + 4.weeks, giro.finito_il.to_date
end

test "does nothing when iniziato_il is blank" do
  giro = @user.giri.new(titolo: "G4")
  giro.valid?
  assert_nil giro.finito_il
end
```

**Step 3: Run tests — fail**

```
docker exec prova-app-1 bin/rails test test/models/giro_test.rb -n "/finito_il/"
```

**Step 4: Implement callback**

In `app/models/giro.rb`, sotto le validazioni, prima di `broadcasts_to`:

```ruby
before_validation :set_default_finito_il
```

E nei metodi privati (dopo `def normalize_arrays`), aggiungi:

```ruby
def set_default_finito_il
  return unless iniziato_il.present?
  return if finito_il.present? && finito_il >= iniziato_il

  self.finito_il = iniziato_il + 4.weeks
end
```

**Step 5: Run tests — pass**

**Step 6: Commit**

```bash
git add app/models/giro.rb test/models/giro_test.rb
git commit -m "feat(giro): move finito_il default to before_validation callback"
```

---

## Task 4: Metodi presentazione su `Giro`

Sposta `genera_settimane`, `genera_giorni_timeline` e calcoli del planner dal controller al modello.

**Files:**
- Modify: `app/models/giro.rb`
- Test: `test/models/giro_test.rb`

**Step 1: Write failing tests**

```ruby
# Task 4 — presentation methods

test "#settimane returns array of weeks covering iniziato_il to finito_il" do
  giro = @user.giri.create!(
    titolo: "G",
    iniziato_il: Date.new(2026, 1, 5),  # Monday
    finito_il:   Date.new(2026, 1, 18)  # Sunday (2 weeks later)
  )
  weeks = giro.settimane
  assert_equal 2, weeks.size
  assert_equal Date.new(2026, 1, 5), weeks.first.first
  assert_equal Date.new(2026, 1, 18), weeks.last.last
end

test "#settimane returns [] when dates blank" do
  giro = @user.giri.new(titolo: "G")
  assert_equal [], giro.settimane
end

test "#settimane returns [] when range > 365 days" do
  giro = @user.giri.new(
    titolo: "G",
    iniziato_il: Date.current,
    finito_il: Date.current + 400
  )
  assert_equal [], giro.settimane
end

test "#giorni_timeline marks today and past" do
  giro = @user.giri.new(titolo: "G")
  tappe_per_giorno = {
    Date.current - 1 => [1, 2],
    Date.current     => [3],
    Date.current + 1 => [4, 5, 6]
  }
  timeline = giro.giorni_timeline(tappe_per_giorno)
  assert_equal 3, timeline.size
  assert timeline[0][:past]
  assert timeline[1][:today]
  refute timeline[2][:past]
  refute timeline[2][:today]
  assert_equal 3, timeline[2][:count]
end
```

**Step 2: Run tests — fail**

```
docker exec prova-app-1 bin/rails test test/models/giro_test.rb -n "/settimane|giorni_timeline/"
```

**Step 3: Implement methods**

In `app/models/giro.rb`, prima dei `private`:

```ruby
def settimane
  return [] unless iniziato_il && finito_il
  dal = iniziato_il.to_date
  al  = finito_il.to_date
  return [] if al < dal || (al - dal).to_i > 365

  (dal.beginning_of_week..al.end_of_week)
    .group_by(&:beginning_of_week)
    .values
end

def giorni_timeline(tappe_per_giorno)
  oggi = Date.current
  tappe_per_giorno.transform_keys { |k| k.to_date }.sort.map do |date, tappe|
    { date: date, count: tappe.size, today: date == oggi, past: date < oggi }
  end
end

def tappe_per_giorno
  tappe.con_data_tappa
    .includes(:tappable, :giri)
    .group_by(&:data_tappa)
end

def tappe_totali
  tappe.size
end

def tappe_completate
  tappe.completate.size
end
```

**Step 4: Run tests — pass**

**Step 5: Commit**

```bash
git add app/models/giro.rb test/models/giro_test.rb
git commit -m "feat(giro): add presentation methods (settimane, giorni_timeline, stats)"
```

---

## Task 5: Aggiorna `broadcasts_to` su `Giro`

Sostituisce il broadcast manuale nel controller con target + inserts_by nel modello.

**Files:**
- Modify: `app/models/giro.rb`

**Step 1: Modifica la stringa `broadcasts_to`**

Da:
```ruby
broadcasts_to ->(giro) { [giro.user, "giri"] }
```
A:
```ruby
broadcasts_to ->(giro) { [giro.user, "giri"] }, target: "giri-lista", inserts_by: :append
```

**Step 2: Run tests**

```
docker exec prova-app-1 bin/rails test test/models/giro_test.rb
```
Expected: tutti passanti.

**Step 3: Commit**

```bash
git add app/models/giro.rb
git commit -m "refactor(giro): set broadcast target to giri-lista with append"
```

**Nota:** I broadcast manuali nel controller vanno rimossi in Task 13 — non toccare ora, per tenere i test verdi mentre migrano.

---

## Task 6: `Filters::TappaFilter::Fields`

Modulo con params permessi e `store_accessor`.

**Files:**
- Create: `app/models/filters/tappa_filter/fields.rb`

**Step 1: Create file**

```ruby
module Filters
  class TappaFilter < Base
    module Fields
      extend ActiveSupport::Concern

      PERMITTED_PARAMS = [
        :search,
        :filter,
        :scuola_id,
        :giro_id,
        :data_inizio,
        :data_fine,
        :area,
        :giorno,
        :week_offset,
        :sort,
        giro_ids: []
      ].freeze

      class_methods do
        def default_values
          {}
        end
      end

      included do
        store_accessor :fields,
          :search, :filter, :scuola_id, :giro_id, :giro_ids,
          :data_inizio, :data_fine, :area, :giorno, :week_offset, :sort

        %i[search filter scuola_id giro_id data_inizio data_fine
           area giorno week_offset sort].each do |attr|
          define_method(attr) { super().presence }
          define_method("#{attr}=") { |v| super(v.presence) }
        end

        def giro_ids
          Array(super).reject(&:blank?).map(&:to_i)
        end

        def giro_ids=(value)
          super(Array(value).reject(&:blank?).map(&:to_s))
        end
      end

      def as_params
        @as_params ||= {
          search: search,
          filter: filter,
          scuola_id: scuola_id,
          giro_id: giro_id,
          giro_ids: giro_ids,
          data_inizio: data_inizio,
          data_fine: data_fine,
          area: area,
          giorno: giorno,
          week_offset: week_offset,
          sort: sort
        }.compact_blank
      end
    end
  end
end
```

**Step 2: Commit (no test: il modulo richiede la classe padre)**

```bash
git add app/models/filters/tappa_filter/fields.rb
git commit -m "feat(tappa_filter): add Fields module with permitted params"
```

---

## Task 7: `Filters::TappaFilter` (main class con query `results`)

**Files:**
- Create: `app/models/filters/tappa_filter.rb`
- Test: `test/models/filters/tappa_filter_test.rb`

**Step 1: Write failing test**

```ruby
require "test_helper"

module Filters
  class TappaFilterTest < ActiveSupport::TestCase
    fixtures :accounts, :users, :memberships, :scuole

    setup do
      @fizzy  = accounts(:fizzy)
      @user   = users(:one)
      @scuola = scuole(:scuola_fizzy)
      Current.account = @fizzy
      Current.user = @user

      @t_oggi   = @user.tappe.create!(tappable: @scuola, data_tappa: Date.current)
      @t_domani = @user.tappe.create!(tappable: @scuola, data_tappa: Date.tomorrow)
      @t_nulla  = @user.tappe.create!(tappable: @scuola, data_tappa: nil)
    end

    teardown { Current.reset }

    test "results returns all user tappe when no filter given" do
      filter = TappaFilter.from_params({})
      assert_equal 3, filter.results(@user.tappe).count
    end

    test "filter 'oggi' returns only today's tappe" do
      filter = TappaFilter.from_params(filter: "oggi")
      result = filter.results(@user.tappe)
      assert_includes result, @t_oggi
      assert_not_includes result, @t_domani
    end

    test "filter 'da_programmare' returns tappe without data_tappa" do
      filter = TappaFilter.from_params(filter: "da_programmare")
      result = filter.results(@user.tappe)
      assert_includes result, @t_nulla
      assert_not_includes result, @t_oggi
    end

    test "scuola_id narrows to one school" do
      other_scuola = Scuola.create!(account: @fizzy, denominazione: "Other", codice: "ZZZ")
      other_tappa  = @user.tappe.create!(tappable: other_scuola, data_tappa: Date.current)

      filter = TappaFilter.from_params(scuola_id: other_scuola.id)
      result = filter.results(@user.tappe)
      assert_includes result, other_tappa
      assert_not_includes result, @t_oggi
    end
  end
end
```

**Step 2: Run tests — fail**

```
docker exec prova-app-1 bin/rails test test/models/filters/tappa_filter_test.rb
```
Expected: `uninitialized constant Filters::TappaFilter`

**Step 3: Create main class**

`app/models/filters/tappa_filter.rb`:

```ruby
module Filters
  class TappaFilter < Base
    include TappaFilter::Fields

    def results(base_scope = nil)
      scope = base_scope || ::Tappa.where(account: account || Current.account)

      scope = apply_filter(scope)
      scope = apply_giro(scope)
      scope = apply_scuola(scope)
      scope = apply_date_range(scope)
      scope = apply_giorno(scope)
      scope = apply_area(scope)
      scope = apply_search(scope)
      scope = apply_week_offset(scope)
      scope = apply_sort(scope)

      scope.includes(:tappable, :giri)
    end

    def settimana_info
      return [nil, nil, 0] if week_offset.blank? && filter != "settimana"
      offset = week_offset.to_i
      start = Date.current.beginning_of_week + offset.weeks
      [start, start.end_of_week, offset]
    end

    private

    def apply_filter(scope)
      case filter
      when "oggi"           then scope.di_oggi
      when "domani"         then scope.di_domani
      when "settimana"      then scope.della_settimana(Date.current)
      when "mese"           then scope.del_mese(Date.current)
      when "programmate"    then scope.programmate
      when "completate"     then scope.completate
      when "da_programmare" then scope.da_programmare
      else scope
      end
    end

    def apply_giro(scope)
      if giro_ids.present?
        scope.joins(:giri).where(giri: { id: giro_ids }).distinct
      elsif giro_id.present?
        scope.joins(:giri).where(giri: { id: giro_id }).distinct
      else
        scope
      end
    end

    def apply_scuola(scope)
      return scope if scuola_id.blank?
      scope.where(tappable_type: "Scuola", tappable_id: scuola_id)
    end

    def apply_date_range(scope)
      return scope if data_inizio.blank? || data_fine.blank?
      scope.where(data_tappa: data_inizio..data_fine)
    end

    def apply_giorno(scope)
      return scope if giorno.blank?
      scope.del_giorno(giorno)
    end

    def apply_area(scope)
      return scope if area.blank?
      scope.dell_area(area)
    end

    def apply_search(scope)
      return scope if search.blank?
      scope.search(search)
    end

    def apply_week_offset(scope)
      return scope if week_offset.blank?
      scope.per_settimana(week_offset.to_i)
    end

    def apply_sort(scope)
      case sort
      when "per_data"           then scope.per_data
      when "per_data_desc"      then scope.per_data_desc
      when "per_ordine_e_data"  then scope.per_ordine_e_data
      else scope.order(data_tappa: :asc, position: :asc)
      end
    end
  end
end
```

**Step 4: Run tests — pass**

```
docker exec prova-app-1 bin/rails test test/models/filters/tappa_filter_test.rb
```

**Step 5: Commit**

```bash
git add app/models/filters/tappa_filter.rb test/models/filters/tappa_filter_test.rb
git commit -m "feat(tappa_filter): add main class with results query"
```

---

## Task 8: `Filters::TappaFilter::Filtering`

Helper per le view (metadata filtri UI). Struttura come `DocumentoFilter::Filtering`.

**Files:**
- Create: `app/models/filters/tappa_filter/filtering.rb`

**Step 1: Create file**

```ruby
module Filters
  class TappaFilter::Filtering
    attr_reader :user, :filter, :expanded

    def initialize(user, filter, expanded: false)
      @user = user
      @filter = filter
      @expanded = expanded
    end

    def expanded?
      expanded || filters_active?
    end

    def filtri_disponibili
      {
        "oggi" => "Oggi",
        "domani" => "Domani",
        "settimana" => "Settimana",
        "mese" => "Mese",
        "programmate" => "Programmate",
        "completate" => "Completate",
        "da_programmare" => "Da programmare"
      }
    end

    def show_filtri?
      filter.filter.present?
    end

    def giri_disponibili
      @giri_disponibili ||= user.giri.order(created_at: :desc).pluck(:id, :titolo)
    end

    def show_giri?
      filter.giro_ids.any? || filter.giro_id.present?
    end

    def aree_disponibili
      @aree_disponibili ||= Scuola.where.not(area: [nil, ""]).distinct.pluck(:area).sort
    end

    def show_aree?
      filter.area.present?
    end

    def sort_options
      {
        "" => "Predefinito",
        "per_data" => "Per data",
        "per_data_desc" => "Per data (desc)",
        "per_ordine_e_data" => "Per ordine e data"
      }
    end

    def filters_active?
      filter.used?
    end

    def controls
      %w[filtri giri aree sort]
    end

    def cache_key
      ["filters/tappa_filtering", user.id, filter.params_digest, expanded].join("/")
    end
  end
end
```

**Step 2: Commit**

```bash
git add app/models/filters/tappa_filter/filtering.rb
git commit -m "feat(tappa_filter): add Filtering helper class for view metadata"
```

---

## Task 9: `Filters::TappaFilter::Summarized`

Conteggi per badge (opzionale ma coerente col pattern).

**Files:**
- Create: `app/models/filters/tappa_filter/summarized.rb`

**Step 1: Create file**

```ruby
module Filters
  class TappaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def count_oggi
        scope = ::Tappa.where(account: account || Current.account, user: creator)
        scope.di_oggi.count
      end

      def count_domani
        scope = ::Tappa.where(account: account || Current.account, user: creator)
        scope.di_domani.count
      end

      def count_programmate
        scope = ::Tappa.where(account: account || Current.account, user: creator)
        scope.programmate.count
      end

      def count_da_programmare
        scope = ::Tappa.where(account: account || Current.account, user: creator)
        scope.da_programmare.count
      end
    end
  end
end
```

**Step 2: Include in main class**

Edit `app/models/filters/tappa_filter.rb`, aggiungi subito dopo `include TappaFilter::Fields`:

```ruby
include TappaFilter::Summarized
```

**Step 3: Run all filter tests — pass**

```
docker exec prova-app-1 bin/rails test test/models/filters/tappa_filter_test.rb
```

**Step 4: Commit**

```bash
git add app/models/filters/tappa_filter/summarized.rb app/models/filters/tappa_filter.rb
git commit -m "feat(tappa_filter): add Summarized counts module"
```

---

## Task 10: Thin `GiriController#show`

Sostituisce i calcoli inline con chiamate ai metodi del modello (senza ancora rimuovere `planner_tappe_per_area` e i broadcast).

**Files:**
- Modify: `app/controllers/giri_controller.rb`
- Modify: `app/views/giri/show.html.erb` (se usa ivar rimossi)

**Step 1: Check la view**

```
docker exec prova-app-1 grep -n "settimane\|tappe_per_area\|tappe_per_giorno\|planner_total\|tappe_totali\|tappe_completate\|giorni_timeline" app/views/giri/show.html.erb
```

Annota quali ivar sono usati nella view.

**Step 2: Modifica `show`**

Sostituisci il metodo `show` attuale (righe 13-29) con:

```ruby
def show
  return respond_to { |format| format.json } if request.format.json?

  @tappe_per_giorno = @giro.tappe_per_giorno
  @tappe_per_area = @giro.tappe.da_programmare.raggruppate_per_area
  @planner_total = @tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }
end
```

**Step 3: Aggiorna la view per leggere dai metodi del modello**

Nella view `app/views/giri/show.html.erb` sostituisci:
- `@settimane` → `@giro.settimane`
- `@tappe_totali` → `@giro.tappe_totali`
- `@tappe_completate` → `@giro.tappe_completate`
- `@giorni_timeline` → `@giro.giorni_timeline(@tappe_per_giorno)`

**Step 4: Modifica `planner` action (righe 31-40)**

```ruby
def planner
  tappe_per_area = @giro.tappe.da_programmare.raggruppate_per_area
  total_count = tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }

  render partial: "giri/planner", locals: {
    giro: @giro,
    tappe_per_area: tappe_per_area,
    total_count: total_count
  }
end
```

**Step 5: Rimuovi i private helper obsoleti**

Da `app/controllers/giri_controller.rb` rimuovi:
- `set_default_finito_il` (righe 107-112) — ora callback
- `genera_settimane` (118-126)
- `genera_giorni_timeline` (128-133)
- `planner_tappe_per_area` (135-156)

**Step 6: Rimuovi le chiamate a `set_default_finito_il` da create/update**

In `create`: rimuovi la riga `set_default_finito_il(@giro)` dopo `@giro = current_user.giri.build(giro_params)`.
In `update`: rimuovi la riga `set_default_finito_il(@giro)` dopo `@giro.assign_attributes(giro_params)`.

**Step 7: Run tests — pass**

```
docker exec prova-app-1 bin/rails test
```

**Step 8: Browser smoke test**

Apri `http://localhost:3000/giri` e entra in un giro: verifica che `show` renderizza senza errori (planner, settimane, timeline).

**Step 9: Commit**

```bash
git add app/controllers/giri_controller.rb app/views/giri/show.html.erb
git commit -m "refactor(giri_controller): slim show/planner, use model methods"
```

---

## Task 11: Thin `TappeController#index`

Usa `Filters::TappaFilter` + `FilterScoped`.

**Files:**
- Modify: `app/controllers/tappe_controller.rb`
- Modify: view `app/views/tappe/index.html.erb` (aggiornare riferimenti se usano i vecchi ivar)

**Step 1: Check la view**

```
docker exec prova-app-1 grep -n "@giro\b\|@scuola\|@current_week_start\|@current_week_end\|@week_offset\|@tappe_raggruppate\|@giri_disponibili" app/views/tappe/index.html.erb
```

**Step 2: Aggiungi `FilterScoped` e `FILTER_PARAMS`**

In cima al controller, prima del `before_action`:

```ruby
include FilterScoped

FILTER_PARAMS = Filters::TappaFilter::Fields::PERMITTED_PARAMS

skip_before_action :set_user_filtering, if: -> { request.format.json? }
```

**Step 3: Riscrivi `index`**

```ruby
def index
  base = current_user.tappe

  if request.format.json?
    @tappe = @filter.results(base).order(data_tappa: :asc, position: :asc)
                   .limit(params[:limit] || 50)
    return respond_to { |format| format.json }
  end

  @tappe = @filter.results(base).where.not(data_tappa: nil)

  # Set @scuola e @giro se filtrati (per la view)
  @scuola = current_account.scuole.find(@filter.scuola_id) if @filter.scuola_id.present?
  @giro   = current_user.giri.find(@filter.giro_id) if @filter.giro_id.present?

  @current_week_start, @current_week_end, @week_offset = @filter.settimana_info

  @tappe_raggruppate = @tappe.group_by(&:data_tappa)
  @giri_disponibili = current_user.giri.order(created_at: :desc)

  respond_to do |format|
    format.html do
      if @filter.scuola_id.present? && @filter.sort == "per_data"
        render partial: "tappe_scuola", locals: { tappe: @tappe }
      end
    end
    format.xlsx
    format.turbo_stream
  end
end
```

**Step 4: Rimuovi i private helper obsoleti**

Da `app/controllers/tappe_controller.rb` rimuovi:
- `planner_tappe_per_area` (righe 249-265)
- `giro_planner_tappe_per_area` (267-282)

**Step 5: Aggiorna `sort` action per usare lo scope**

Nel metodo `sort` (righe 182-202), sostituisci:
```ruby
if params[:giro_id].present?
  @planner_tappe_per_area = giro_planner_tappe_per_area(params[:giro_id])
else
  @planner_tappe_per_area = planner_tappe_per_area
end
```
con:
```ruby
scope = params[:giro_id].present? ? current_user.giri.find(params[:giro_id]).tappe : current_user.tappe
@planner_tappe_per_area = scope.da_programmare.raggruppate_per_area
```

**Step 6: Run tests — pass**

```
docker exec prova-app-1 bin/rails test test/controllers/
```

**Step 7: Browser smoke**

`http://localhost:3000/tappe` con filtri `?filter=oggi`, `?filter=programmate`, `?week_offset=1`, `?scuola_id=...`.

**Step 8: Commit**

```bash
git add app/controllers/tappe_controller.rb app/views/tappe/index.html.erb
git commit -m "refactor(tappe_controller): use TappaFilter + FilterScoped for index"
```

---

## Task 12: Estrai `Giri::PlannersController`

Sposta l'azione `planner` in controller dedicato.

**Files:**
- Create: `app/controllers/giri/planners_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/giri_controller.rb` (rimuovi `planner`)
- Modify: view(s) che puntano a `planner_giro_path`

**Step 1: Trova chi chiama l'attuale `planner`**

```
docker exec prova-app-1 grep -rn "planner_giro_path\|planner_giro_url" app/views app/javascript
```

Annota i path.

**Step 2: Aggiungi route**

In `config/routes.rb`, trova `resources :giri` e cambia in:

```ruby
resources :giri do
  resource :planner, module: :giri, only: :show, controller: "planners"
  member do
    get :copia
  end
end
```

(Nota: tengo `copia` come membro per ora — Task 13 lo sposterà.)

Rimuovi `member { get :planner }` se presente.

**Step 3: Create il controller**

`app/controllers/giri/planners_controller.rb`:

```ruby
class Giri::PlannersController < ApplicationController
  before_action :authenticate_user!

  def show
    @giro = current_user.giri.find(params[:giro_id])
    tappe_per_area = @giro.tappe.da_programmare.raggruppate_per_area
    total_count = tappe_per_area.sum { |_, dirs| dirs.sum { |_, t| t.size } }

    render partial: "giri/planner", locals: {
      giro: @giro,
      tappe_per_area: tappe_per_area,
      total_count: total_count
    }
  end
end
```

**Step 4: Rimuovi `planner` da `GiriController`**

Rimuovi il metodo `planner` (righe ~31-40) e rimuovi `:planner` da `before_action :set_giro, only: [...]`.

**Step 5: Aggiorna view/JS**

In ogni file trovato allo Step 1, sostituisci:
- `planner_giro_path(@giro)` → `giro_planner_path(@giro)`
- `planner_giro_url(@giro)` → `giro_planner_url(@giro)`

**Step 6: Run tests + routes**

```
docker exec prova-app-1 bin/rails routes | grep planner
docker exec prova-app-1 bin/rails test
```

**Step 7: Browser smoke**

Apri il planner di un giro nell'UI.

**Step 8: Commit**

```bash
git add config/routes.rb app/controllers/giri/planners_controller.rb app/controllers/giri_controller.rb app/views app/javascript
git commit -m "refactor(giri): extract planner action to Giri::PlannersController"
```

---

## Task 13: Estrai `Giri::CopieController`

**Files:**
- Create: `app/controllers/giri/copie_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/giri_controller.rb` (rimuovi `copia`)
- Modify: view `app/views/giri/copia.html.erb` → sposta in `app/views/giri/copie/new.html.erb`
- Modify: view che chiamano `copia_giro_path`

**Step 1: Find callers**

```
docker exec prova-app-1 grep -rn "copia_giro_path\|copia_giro_url" app/views app/javascript
```

**Step 2: Aggiorna route**

In `config/routes.rb`:
```ruby
resources :giri do
  resource :planner, module: :giri, only: :show, controller: "planners"
  resource :copia,   module: :giri, only: [:new, :create], controller: "copie"
end
```

Rimuovi `member { get :copia }`.

**Step 3: Create controller**

`app/controllers/giri/copie_controller.rb`:

```ruby
class Giri::CopieController < ApplicationController
  before_action :authenticate_user!

  def new
    @giro = current_user.giri.find(params[:giro_id])
    @altri_giri = current_user.giri.where.not(id: @giro.id).order(created_at: :desc)
  end

  # Aggiungi create solo se esiste già logica di copia in qualche posto.
  # Altrimenti lascia solo new.
end
```

**Step 4: Sposta la view**

```
docker exec prova-app-1 mkdir -p app/views/giri/copie
git mv app/views/giri/copia.html.erb app/views/giri/copie/new.html.erb
```

(Se esiste solo come template, sposta + rinomina.)

**Step 5: Rimuovi `copia` da `GiriController`**

Rimuovi il metodo `copia` (righe 42-44) e `:copia` da `before_action :set_giro, only: [...]`.

**Step 6: Aggiorna view/JS**

Sostituisci:
- `copia_giro_path(giro)` → `new_giro_copia_path(giro)`
- `copia_giro_url(giro)` → `new_giro_copia_url(giro)`

**Step 7: Run tests**

```
docker exec prova-app-1 bin/rails routes | grep -i copia
docker exec prova-app-1 bin/rails test
```

**Step 8: Browser smoke**

Apri la pagina "copia" di un giro.

**Step 9: Commit**

```bash
git add .
git commit -m "refactor(giri): extract copia action to Giri::CopieController"
```

---

## Task 14: Estrai `Tappe::SortsController`

Sposta l'azione `sort`.

**Files:**
- Create: `app/controllers/tappe/sorts_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/tappe_controller.rb` (rimuovi `sort`)
- Modify: view/JS che chiamano `sort_tappa_path`

**Step 1: Find callers**

```
docker exec prova-app-1 grep -rn "sort_tappa" app/views app/javascript
```

**Step 2: Update routes**

```ruby
resources :tappe do
  resource :sort, module: :tappe, only: :update, controller: "sorts"
end
```

Rimuovi eventuali `member { patch :sort }` o `collection { patch :sort }`.

**Step 3: Create controller**

`app/controllers/tappe/sorts_controller.rb`:

```ruby
class Tappe::SortsController < ApplicationController
  before_action :authenticate_user!

  def update
    @tappa = current_user.tappe.find(params[:tappa_id])
    @tappa.update(position: params[:position].to_i, data_tappa: params[:data_tappa])

    if params[:source] == "to_planner"
      scope = params[:giro_id].present? ? current_user.giri.find(params[:giro_id]).tappe : current_user.tappe
      @planner_tappe_per_area = scope.da_programmare.raggruppate_per_area
    end

    respond_to do |format|
      format.turbo_stream
      format.html { head :no_content }
    end
  end
end
```

**Step 4: Rimuovi `sort` da `TappeController`**

Rimuovi il metodo `sort` (righe 182-202).

**Step 5: Aggiorna view/JS**

Sostituisci `sort_tappa_path(tappa)` → `tappa_sort_path(tappa)`.

Se la view `sort.turbo_stream.erb` esiste, spostala: `git mv app/views/tappe/sort.turbo_stream.erb app/views/tappe/sorts/update.turbo_stream.erb` (crea `app/views/tappe/sorts/` se serve).

**Step 6: Run tests + browser smoke (drag&drop nel planner)**

```
docker exec prova-app-1 bin/rails test
```

**Step 7: Commit**

```bash
git add .
git commit -m "refactor(tappe): extract sort action to Tappe::SortsController"
```

---

## Task 15: Estrai `Tappe::RimandiController`

**Files:**
- Create: `app/controllers/tappe/rimandi_controller.rb`
- Modify: `config/routes.rb`
- Modify: `app/controllers/tappe_controller.rb` (rimuovi `rimanda`)
- Modify: view/JS che chiamano `rimanda_tappa_path`

**Step 1: Find callers**

```
docker exec prova-app-1 grep -rn "rimanda_tappa" app/views app/javascript
```

**Step 2: Update routes**

```ruby
resources :tappe do
  resource :sort,    module: :tappe, only: :update, controller: "sorts"
  resource :rimando, module: :tappe, only: :create, controller: "rimandi"
end
```

**Step 3: Create controller**

`app/controllers/tappe/rimandi_controller.rb`:

```ruby
class Tappe::RimandiController < ApplicationController
  before_action :authenticate_user!

  def create
    @tappa = current_user.tappe.find(params[:tappa_id])
    giorno = @tappa.data_tappa
    @tappa.update!(data_tappa: nil)

    respond_to do |format|
      format.turbo_stream { redirect_to giorno_path(giorno: giorno || Date.current), notice: "Tappa rimandata.", status: :see_other }
      format.html { redirect_to giorno_path(giorno: giorno || Date.current), notice: "Tappa rimandata." }
    end
  end
end
```

**Step 4: Rimuovi `rimanda` da `TappeController`**

Rimuovi il metodo `rimanda` (righe 204-212) e `:rimanda` da `before_action :set_tappa, only: [...]`.

**Step 5: Aggiorna view/JS**

Sostituisci:
- `rimanda_tappa_path(tappa)` → `tappa_rimando_path(tappa)` (method: POST)

**Step 6: Run tests + smoke**

**Step 7: Commit**

```bash
git add .
git commit -m "refactor(tappe): extract rimanda action to Tappe::RimandiController"
```

---

## Task 16: Rimuovi broadcast manuali da `GiriController`

Ora che il modello ha `target: "giri-lista"`, i broadcast manuali in `create`/`update` sono ridondanti.

**Files:**
- Modify: `app/controllers/giri_controller.rb`

**Step 1: Rimuovi righe**

In `create` (riga 60) rimuovi:
```ruby
@giro.broadcast_append_later_to [current_user, "giri"], target: "giri-lista"
```

In `update` (riga 79) rimuovi:
```ruby
@giro.broadcast_replace_later_to [current_user, "giri"]
```

**Step 2: Run tests**

```
docker exec prova-app-1 bin/rails test
```

**Step 3: Browser smoke**

Apri la pagina `/giri` in due tab, crea un giro in una tab, verifica che appare nell'altra (broadcast append). Modifica un giro, verifica che la card si aggiorna (broadcast replace).

**Step 4: Commit**

```bash
git add app/controllers/giri_controller.rb
git commit -m "refactor(giri_controller): remove manual broadcasts, rely on model"
```

---

## Task 17: Verifica finale

**Step 1: Full test suite**

```
docker exec prova-app-1 bin/rails test
```
Expected: tutti verdi, nessun skip nuovo.

**Step 2: Routes review**

```
docker exec prova-app-1 bin/rails routes | grep -E "giri|tappe" | head -40
```

Verifica che le nuove route (planner, copia, sort, rimando) siano presenti e sensate.

**Step 3: Browser checklist**

- `/giri` — index renderizza, crea/modifica → broadcast funzionanti
- `/giri/:id` — show con planner, settimane, timeline
- `/giri/:id/planner` — rendering planner (partial)
- `/giri/:id/copia/new` — form di copia
- `/tappe` — con filtri `filter=oggi`, `week_offset=1`, `giro_id=X`, `scuola_id=Y`
- `/tappe/:id` — show
- Drag & drop nel planner → `Tappe::SortsController#update`
- Rimanda una tappa → `Tappe::RimandiController#create`

**Step 4: Diff review**

```
git log --oneline feature/multi-tenancy..HEAD
git diff feature/multi-tenancy..HEAD --stat
```

**Step 5: Cleanup**

Rivedi:
- Nessun metodo privato morto nei controller
- Nessun ivar non usato
- Niente `puts`/`binding.pry` dimenticati

Se trovi qualcosa:
```bash
git add ...
git commit -m "chore: cleanup after refactoring"
```

---

## Out of scope

- Test di controller nuovi (solo test modello + filter). Se serve coverage sui controller, aggiungerli in una sessione successiva.
- Refactoring di altre azioni in `TappeController` non citate (show, new, create, update, destroy).
- Miglioramenti CSS/view oltre quelli necessari per far funzionare i path aggiornati.
- `referrer_back_info` / `back_link_to` restano invariati (presentation).
