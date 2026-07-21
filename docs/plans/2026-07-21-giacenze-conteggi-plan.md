# Giacenze → Conteggi per anno — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans / subagent-driven-development to implement this plan task-by-task.
> **IMPORTANTE:** NON committare mai — Paolo committa a mano. Tutti i comandi Rails vanno eseguiti nel container: `docker exec prova-app-1 bin/rails ...`
> Design di riferimento: `docs/plans/2026-07-21-giacenze-conteggi-design.md` (leggerlo prima di iniziare).

**Goal:** La pagina `/giacenze` abbandona fabbisogno/disponibilità (dati incompleti) e mostra conteggi per libro filtrabili per anno: Adottati, Campionario, Saggi 100, Saggi 50, Scarico saggi, Venduti, Da consegnare.

**Architecture:** Un PORO `Giacenza::Conteggi` genera una subquery SQL (GROUP BY `righe.libro_id`, un `FILTER` per colonna, filtro anno su `data_documento`) che il `GiacenzaFilter` joina sulla scope dei libri. Niente denormalizzazione: la pagina smette di leggere la tabella `giacenze` (tabella e modello restano per gli altri consumer). I conteggi per causale sono quantità piene senza segno; venduti/da consegnare riusano la logica a segni di `Giacenza::AGGREGATI_SQL`.

**Tech Stack:** Rails 8.1, PostgreSQL (FILTER/LATERAL), Minitest + fixtures, pattern esistenti: `FilterScoped`, `HasVista`, `DataTable::Columns`.

**Vincoli di dominio (dal design):**
- I conteggi NON si sommano tra loro: letture parallele dello stesso anno.
- Mapping causali per NOME (`causali.causale`): "Campionario", "saggi 100", "saggi 50", "Scarico saggi". La causale "saggi" va rinominata "saggi 100" via migration.
- Escludere sempre i documenti figli (`documento_padre_id IS NOT NULL`).
- `venduti` conta solo le copie consegnate (`consegna_righe`), col segno (`Causale::SEGNO_SQL` negato) così le note credito sottraggono; `da_consegnare` è il residuo non consegnato, sempre col segno. Entrambi solo su `causali.magazzino = 'vendita' AND causali.tipo_movimento = 1`.
- `venduto_cents` (per la card in €) usa il prezzo scontato: `righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore` con `divisore = Giacenza.divisore_sconto(account)`.

---

### Task 1: Migration rename causale "saggi" → "saggi 100" + fixtures causali campionario

**Files:**
- Create: `db/migrate/<timestamp>_rename_causale_saggi_in_saggi_100.rb` (genera con `docker exec prova-app-1 bin/rails generate migration RenameCausaleSaggiInSaggi100`)
- Modify: `test/fixtures/causali.yml`

**Step 1: Migration (data-fix, reversibile)**

```ruby
class RenameCausaleSaggiInSaggi100 < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE causali SET causale = 'saggi 100' WHERE causale = 'saggi'"
  end

  def down
    execute "UPDATE causali SET causale = 'saggi' WHERE causale = 'saggi 100'"
  end
end
```

**Step 2: Aggiungi fixtures in `test/fixtures/causali.yml`** (in coda al file; rispetta lo stile esistente — enum come interi: movimento entrata=0/uscita=1, tipo_movimento ordine=0/vendita=1/carico=2):

```yaml
campionario:
  causale: "Campionario"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 0
  gestione_pagamento: false
  gestione_consegna: false

saggi_100:
  causale: "saggi 100"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 1
  gestione_pagamento: false
  gestione_consegna: false

saggi_50:
  causale: "saggi 50"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 1
  gestione_pagamento: false
  gestione_consegna: false

scarico_saggi:
  causale: "Scarico saggi"
  magazzino: "campionario"
  tipo_movimento: 2
  movimento: 1
  gestione_pagamento: false
  gestione_consegna: false
```

**Step 3: Migra e verifica**

```
docker exec prova-app-1 bin/rails db:migrate
docker exec prova-app-1 bin/rails runner 'puts Causale.where("causale ILIKE ?", "%saggi%").pluck(:causale)'
```
Atteso: `saggi 100`, `saggi 50`, `Scarico saggi` (niente più "saggi" da solo).

**Step 4: Lancia i test dei modelli per assicurarti che le nuove fixture non rompano nulla**

```
docker exec prova-app-1 bin/rails test test/models/
```
Se qualche test contava le causali (`Causale.count`), aggiornalo.

---

### Task 2: PORO `Giacenza::Conteggi` con test (TDD)

**Files:**
- Create: `app/models/giacenza/conteggi.rb`
- Test: `test/models/giacenza/conteggi_test.rb`

Leggi PRIMA `app/models/giacenza.rb` (AGGREGATI_SQL/FONTE_SQL: la fonte è identica, cambia l'aggregazione) e `test/models/giacenza_test.rb` (helper `crea_documento`/`ricalcola`: replica lo stile per creare documenti+righe nei test).

**Step 1: Scrivi il test (fallirà: classe inesistente)**

`test/models/giacenza/conteggi_test.rb` — usa le stesse fixtures/setup di `giacenza_test.rb` (account fizzy, libro dedicato creato nel setup per non farsi inquinare dalle fixture righe). Casi da coprire:

1. **Conteggi per causale rispettano causale e anno**: crea un documento "Campionario" con 10 copie datato quest'anno e uno datato anno scorso con 4; `per_libro` di quest'anno riporta `campionario: 10`; quello dell'anno scorso `campionario: 4`.
2. **Le quattro causali finiscono in colonne distinte**: un documento per ciascuna causale (campionario 10, saggi_100 3, saggi_50 2, scarico_saggi 5) → hash con i quattro valori distinti, senza somme incrociate.
3. **Venduti = solo copie consegnate, da_consegnare = residuo**: documento vendita da 6 copie con 4 consegnate (crea `Consegna`+`consegna_righe` come fa `giacenza_test.rb`) → `venduti: 4`, `da_consegnare: 2`.
4. **I documenti figli sono esclusi**: fattura figlia (`documento_padre_id`) che condivide le righe del padre → conteggi invariati.
5. **`totali` somma sui libri filtrati**: `totali` su scope di due libri → somme aggregate; verifica anche `venduto_cents`.

Esempio di struttura (adatta gli helper a quelli reali di `giacenza_test.rb`):

```ruby
require "test_helper"

class Giacenza::ConteggiTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti, :causali, :categorie, :editori, :libri

  setup do
    @account = accounts(:fizzy)
    @user = users(:one)
    @cliente = clienti(:cliente_fizzy)
    Current.account = @account
    Current.user = @user
    @libro = Libro.create!(account: @account, user: @user, titolo: "Libro conteggi",
                           codice_isbn: "TEST-CONT-1", prezzo_in_cents: 10000,
                           categoria: categorie(:ministeriali))
  end

  teardown { Current.reset }

  test "conta le copie campionario per anno" do
    crea_documento(causali(:campionario), quantita: 10)
    crea_documento(causali(:campionario), quantita: 4, data: 1.year.ago.to_date)

    assert_equal 10, conteggi_libro[:campionario]
    assert_equal 4, conteggi_libro(anno: 1.year.ago.year)[:campionario]
  end

  # ... (altri casi come sopra)

  private

    def conteggi_libro(anno: Date.current.year)
      Giacenza::Conteggi.new(account: @account, anno: anno).per_libro[@libro.id]
    end

    def crea_documento(causale, quantita:, data: Date.current, prezzo_cents: 1000, sconto: 0)
      # replica l'helper di giacenza_test.rb aggiungendo data_documento: data
    end
end
```

**Step 2: Verifica che fallisca**

```
docker exec prova-app-1 bin/rails test test/models/giacenza/conteggi_test.rb
```
Atteso: NameError / uninitialized constant.

**Step 3: Implementa `app/models/giacenza/conteggi.rb`**

```ruby
# Conteggi annuali per libro della pagina giacenze: colonne per causale
# (quantità piene, senza segni: riferimenti, non saldi) più venduti e
# da consegnare (logica a segni dei documenti vendita, come Giacenza).
class Giacenza::Conteggi
  CAUSALI = {
    campionario:   "Campionario",
    saggi_100:     "saggi 100",
    saggi_50:      "saggi 50",
    scarico_saggi: "Scarico saggi"
  }.freeze

  VENDITA_SQL = "causali.magazzino = 'vendita' AND causali.tipo_movimento = 1".freeze

  AGGREGATI_SQL = <<~SQL.freeze
    #{CAUSALI.map { |chiave, nome|
      "COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = #{ActiveRecord::Base.connection.quote(nome)}), 0)::integer AS #{chiave}"
    }.join(",\n")},
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0))
      FILTER (WHERE #{VENDITA_SQL}), 0)::integer AS venduti,
    COALESCE(SUM(-(#{Causale::SEGNO_SQL}) * (righe.quantita - COALESCE(cons.consegnate, 0)))
      FILTER (WHERE #{VENDITA_SQL}), 0)::integer AS da_consegnare,
    COALESCE(ROUND(SUM(-(#{Causale::SEGNO_SQL}) * COALESCE(cons.consegnate, 0) *
        (righe.prezzo_cents - righe.prezzo_cents * righe.sconto / :divisore))
      FILTER (WHERE #{VENDITA_SQL})), 0)::bigint AS venduto_cents
  SQL

  # Stessa fonte di Giacenza::FONTE_SQL più il filtro anno.
  FONTE_SQL = <<~SQL.freeze
    #{Giacenza::FONTE_SQL}
      AND EXTRACT(YEAR FROM documenti.data_documento) = :anno
  SQL

  attr_reader :account, :anno

  def initialize(account:, anno:)
    @account = account
    @anno = anno.to_i
  end

  # SQL della subquery (libro_id + aggregati) da joinare sulla scope dei libri.
  def subquery
    sanitize(<<~SQL)
      SELECT righe.libro_id, #{AGGREGATI_SQL}
      #{FONTE_SQL}
      GROUP BY righe.libro_id
    SQL
  end

  # Hash libro_id => conteggi (chiavi simboliche) per i libri dati.
  def per_libro(libro_ids = nil)
    sql = <<~SQL
      SELECT righe.libro_id, #{AGGREGATI_SQL}
      #{FONTE_SQL}
      #{"AND righe.libro_id IN (:libro_ids)" if libro_ids}
      GROUP BY righe.libro_id
    SQL
    ActiveRecord::Base.connection.select_all(sanitize(sql, libro_ids: libro_ids))
      .index_by { |row| row["libro_id"] }
      .transform_values { |row| row.except("libro_id").symbolize_keys }
  end

  private

    def sanitize(sql, extra = {})
      ActiveRecord::Base.sanitize_sql_array([
        sql, { account_id: account.id, anno: anno, divisore: Giacenza.divisore_sconto(account) }.merge(extra)
      ])
    end
end
```

Nota: la costante `AGGREGATI_SQL` con `connection.quote` a load-time può dare problemi in boot senza DB — se succede, rendila un metodo di classe memoizzato o usa apici singoli letterali (i nomi causale sono costanti note senza apici: `'Campionario'` va benissimo scritto a mano). Preferisci la versione semplice a mano:

```ruby
COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'Campionario'), 0)::integer AS campionario,
COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'saggi 100'), 0)::integer AS saggi_100,
COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'saggi 50'), 0)::integer AS saggi_50,
COALESCE(SUM(righe.quantita) FILTER (WHERE causali.causale = 'Scarico saggi'), 0)::integer AS scarico_saggi,
```

(mantieni comunque la costante `CAUSALI` come documentazione/mapping per il resto del codice).

`totali` NON va qui: si calcola nel controller sommando le colonne della subquery joinata, così rispetta i filtri attivi (vedi Task 4).

**Step 4: Test verdi**

```
docker exec prova-app-1 bin/rails test test/models/giacenza/conteggi_test.rb
```
Atteso: PASS. NON committare.

---

### Task 3: `GiacenzaFilter` — join conteggi, nuovi STATI, campo anno

**Files:**
- Modify: `app/models/filters/giacenza_filter.rb`
- Modify: `app/models/filters/giacenza_filter/fields.rb`
- Modify: `app/models/filters/giacenza_filter/filtering.rb`
- Modify: `app/models/filters/giacenza_filter/summarized.rb`

**Step 1: `giacenza_filter.rb`** — nuovi STATI e join della subquery:

```ruby
module Filters
  class GiacenzaFilter < Base
    include GiacenzaFilter::Fields
    include GiacenzaFilter::Summarized

    STATI = {
      "adottati"    => "Adottati",
      "impegnati"   => "Da consegnare",
      "campionario" => "In campionario",
      "venduti"     => "Venduti"
    }.freeze

    def libri
      target_account = account || Current.account
      conteggi = Giacenza::Conteggi.new(account: target_account, anno: anno)

      result = target_account.libri
        .joins("LEFT JOIN (#{conteggi.subquery}) conteggi ON conteggi.libro_id = libri.id")
        .select("libri.*", *conteggi_select)

      if terms.present?
        ids = target_account.libri.reorder(nil).search_all_word(terms.first).pluck(:id)
        result = result.where(libri: { id: ids })
      end

      result = result.joins(:editore).where(editori: { editore: editori }) if editori.present?

      case stato
      when "adottati"
        result = result.where("libri.adozioni_count > 0")
      when "impegnati"
        result = result.where("COALESCE(conteggi.da_consegnare, 0) > 0")
      when "campionario"
        result = result.where("COALESCE(conteggi.campionario, 0) > 0")
      when "venduti"
        result = result.where("COALESCE(conteggi.venduti, 0) > 0")
      end

      result
    end

    alias_method :results, :libri

    private

      # Alias COALESCE-ati così celle e sort leggono valori mai NULL.
      def conteggi_select
        (Giacenza::Conteggi::CAUSALI.keys + %i[venduti da_consegnare venduto_cents]).map do |col|
          "COALESCE(conteggi.#{col}, 0) AS #{col}"
        end
      end
  end
end
```

Rimuovi `LIBERO_SQL` (qui e ovunque). Commento sul pg_search/DISTINCT: mantieni quello esistente.

**Step 2: `fields.rb`** — aggiungi `anno` (default anno corrente):

- `PERMITTED_PARAMS`: aggiungi `:anno` (prima di `editori: []`).
- `store_accessor`: aggiungi `:anno`.
- Accessor:

```ruby
def anno
  (super.presence || Date.current.year).to_i
end
```

- `default_values`: `{ anno: Date.current.year }` così `as_params` scarta l'anno di default e i filtri salvati non lo fissano.
- `as_params`: aggiungi `params[:anno] = anno`.

**Step 3: `filtering.rb`** — anno nel pannello:

- `controls`: `%w[stato_giacenza anni editori]`.
- Aggiungi (modello: `DocumentoFilter::Filtering`; qui i documenti sono dell'account, non dell'utente):

```ruby
def anni_disponibili
  @anni_disponibili ||= (filter.account || Current.account).documenti
    .distinct.pluck(Arel.sql("EXTRACT(YEAR FROM data_documento)::integer")).compact.sort.reverse
end

def show_anni?
  filter.anno != Date.current.year
end
```

- `filters_active?`: aggiungi `|| filter.anno != Date.current.year`.

Verifica che il partial condiviso `app/views/filters/settings/_anni.html.erb` funzioni così com'è (usa `user_filtering.anni_disponibili`, `filter.anno`, hidden field `anno`): se sì non toccarlo.

**Step 4: `summarized.rb`** — aggiungi `anno_summary`:

```ruby
def summary
  parts = [terms_summary, stato_summary, anno_summary, editori_summary].compact
  parts.any? ? parts.to_sentence : "Tutte le giacenze"
end

def anno_summary
  "anno #{anno}" if anno != Date.current.year
end
```

**Step 5: Verifica veloce da runner**

```
docker exec prova-app-1 bin/rails runner '
  Current.user = User.first; Current.account = Current.user.accounts.first
  f = Filters::GiacenzaFilter.new(account: Current.account, fields: {})
  puts f.libri.limit(3).map { |l| [l.titolo, l[:campionario], l[:venduti], l[:da_consegnare]].inspect }
  puts Filters::GiacenzaFilter.new(account: Current.account, fields: { "stato" => "campionario" }).libri.count
'
```
Atteso: nessun errore SQL, valori numerici. Controlla come `Filters::Base` costruisce le istanze (`new` con `fields:`? `from_params`?) e adatta la verifica.

---

### Task 4: Controller, colonne, celle e vista index

**Files:**
- Modify: `app/controllers/giacenze_controller.rb`
- Modify: `app/models/giacenza/columns.rb`
- Modify: `app/views/giacenze/index.html.erb`
- Modify: `app/views/giacenze/table/_row.html.erb`
- Create/Delete celle in `app/views/giacenze/table/cells/`

**Step 1: `Giacenza::Columns`** — nuovo registro (via `LIBERO_SQL`/`FABBISOGNO_SQL`):

```ruby
# Registro colonne della vista tabella delle giacenze (conteggi per anno).
class Giacenza::Columns < DataTable::Columns
  self.prefix = "giacenze"
  self.checkbox = false

  column :titolo,        label: "Titolo",        width: "minmax(15rem, 1fr)", sort: "libri.titolo"
  column :isbn,          label: "ISBN",          width: "7.5rem", hide_mobile: true, sort: "libri.codice_isbn"
  column :adozioni,      label: "Adottati",      width: "5.5rem", align: :end, hide_mobile: true,
         sort: "libri.adozioni_count"
  column :campionario,   label: "Campionario",   width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.campionario, 0)"
  column :saggi_100,     label: "Saggi 100",     width: "5.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.saggi_100, 0)"
  column :saggi_50,      label: "Saggi 50",      width: "5.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.saggi_50, 0)"
  column :scarico_saggi, label: "Scarico saggi", width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.scarico_saggi, 0)"
  column :venduti,       label: "Venduti",       width: "7rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.venduti, 0)"
  column :da_consegnare, label: "Da consegnare", width: "6.5rem", align: :end, hide_mobile: true,
         sort: "COALESCE(conteggi.da_consegnare, 0)"
end
```

**Step 2: Controller** — totali dalla scope joinata (rispettano i filtri), niente più include `:giacenza`:

```ruby
class GiacenzeController < ApplicationController
  include FilterScoped
  include HasVista

  FILTER_PARAMS = [:stato, :anno, editori: [], terms: []].freeze

  before_action :authenticate_user!

  ORDINE_DEFAULT = "libri.titolo ASC".freeze

  def index
    @columns = resolve_colonne(Giacenza::Columns)
    @sort = resolve_sort(@columns)

    scope = @filter.libri.includes(:editore)

    @totali = totali(scope.except(:includes, :order))
    @total_count = scope.except(:select).count

    scope = @sort.active? ? apply_sort(scope, @sort) : scope.reorder(Arel.sql(ORDINE_DEFAULT))
    set_page_and_extract_portion_from scope
  end

  private

    def totali(scope)
      colonne = %w[campionario scarico_saggi venduti da_consegnare venduto_cents]
      row = scope.except(:select).pick(
        Arel.sql("COALESCE(SUM(libri.adozioni_count), 0)"),
        *colonne.map { |c| Arel.sql("COALESCE(SUM(conteggi.#{c}), 0)") }
      )
      %i[adottati campionario scarico_saggi venduti da_consegnare venduto_cents].zip(row.map(&:to_i)).to_h
    end
end
```

(`except(:select)` prima di `count`/`pick` evita conflitti tra select custom e aggregati.)

**Step 3: `_row.html.erb`** — via la lookup di `giacenza`, le celle leggono gli alias:

```erb
<%# locals: (libro:, columns: nil) -%>

<% columns ||= Giacenza::Columns.visible(cookies[:giacenze_colonne].to_s.split(",")) %>

<%= tag.div id: dom_id(libro, :giacenza),
      class: "data-row",
      style: "--cols: #{Giacenza::Columns.grid_template(columns)};",
      role: "row" do %>

  <% columns.each do |column| %>
    <%= render column.partial, libro: libro %>
  <% end %>
<% end %>
```

ATTENZIONE: `_row` viene renderizzato anche fuori da questa pagina? Verifica con grep (`giacenze/table/row`). Se un broadcast/stream lo usa con un `libro` non arricchito dagli alias, le celle devono degradare con `libro[:campionario].to_i` (gli alias mancanti danno `nil` → `.to_i` → 0). Usa sempre `libro[:chiave].to_i` nelle celle.

**Step 4: Celle.** Elimina `_disponibile`, `_fabbisogno`, `_libero`, `_impegnato`, `_vendute`. Aggiorna `_titolo` (via il blocco `data-row__values` su disponibile/fabbisogno; tieni titolo+editore). `_adozioni` e `_isbn`: solo firma locals `(libro:)`. Crea le nuove, tutte su questo modello:

```erb
<%# locals: (libro:) -%>

<div class="data-row__cell data-row__cell--end data-row__cell--hide-mobile"><%= dash_if_zero(libro[:campionario].to_i) %></div>
```

(`_saggi_100`, `_saggi_50`, `_scarico_saggi`, `_da_consegnare` identiche con la loro chiave). `_venduti` come la vecchia `_vendute` ma con gli alias:

```erb
<%# locals: (libro:) -%>

<div class="data-row__cell data-row__cell--end data-row__cell--hide-mobile">
  <%= dash_if_zero(libro[:venduti].to_i) %>
  <% if libro[:venduti].to_i.positive? %>
    <div class="txt-xx-small txt-subtle"><%= number_to_currency libro[:venduto_cents].to_i / 100.0, locale: :it %></div>
  <% end %>
</div>
```

**Step 5: `index.html.erb`** — card di testata: **Adottati · Campionario · Scarico saggi · Venduti · Da consegnare** + venduto in € (NIENTE card saggi 100/50):

```erb
<div class="analytics-summary">
  <% [
       [:adottati, "adottati", nil],
       [:campionario, "campionario", nil],
       [:scarico_saggi, "scarico saggi", nil],
       [:venduti, "vendute", "txt-positive"],
       [:da_consegnare, "da consegnare", nil]
     ].each do |chiave, etichetta, value_class| %>
    <div class="analytics-summary__card">
      <p class="analytics-summary__value <%= value_class %>"><%= number_with_delimiter(@totali.fetch(chiave)) %></p>
      <p class="analytics-summary__label"><%= etichetta %></p>
    </div>
  <% end %>
  <div class="analytics-summary__card">
    <p class="analytics-summary__value txt-positive"><%= number_to_currency @totali.fetch(:venduto_cents) / 100.0, locale: :it %></p>
    <p class="analytics-summary__label">venduto</p>
  </div>
</div>
```

Rimuovi la frase "Il fabbisogno è dato da adozioni meno disponibilità libera." lasciando il conteggio titoli. Il resto della pagina (filters/settings, data-table, paginazione) resta identico.

**Step 6: Verifica visuale.** Riavvia nulla (autoload), poi indica a Paolo di controllare `http://localhost:3000/giacenze` (NON aprire il browser tu): colonne nuove, card nuove, filtro anno nel pannello, sort su ogni colonna.

---

### Task 5: Test controller e suite completa

**Files:**
- Modify: `test/controllers/giacenze_controller_test.rb`

**Step 1: Riscrivi il test.** Mantieni `sign_in_as`/`sign_cookie` e le fixtures, ma il setup crea documenti veri invece della riga `Giacenza.create!` (replica gli helper `crea_documento` di `test/models/giacenza_test.rb`, parametrizzando `data_documento`). Copertura:

1. **Testata e tabella**: card `analytics-summary` = 6 (adottati, campionario, scarico saggi, vendute, da consegnare, venduto €); nessun match per `/Fabbisogno/`; presenza dei numeri attesi.
2. **Filtro anno**: documento campionario quest'anno (10 copie) e anno scorso (4); default mostra 10; `get giacenze_path(anno: <anno scorso>)` mostra 4.
3. **Filtri stato nuovi**: `stato: "campionario"` e `stato: "venduti"` includono/escludono i libri giusti; `stato: "fabbisogno"` (rimosso) non filtra nulla (stato ignorato → tutti i libri).
4. **Sort su colonna conteggio**: `sort: "campionario.desc"` ordina correttamente (due libri con conteggi diversi).
5. Mantieni i test esistenti su terms, ordina per titolo di default, adottati (invariati nella sostanza).

**Step 2: Lancia i test del controller**

```
docker exec prova-app-1 bin/rails test test/controllers/giacenze_controller_test.rb
```
Atteso: PASS.

**Step 3: Suite completa**

```
docker exec prova-app-1 bin/rails test
```
Atteso: PASS. Se falliscono test estranei preesistenti, segnalalo senza "sistemarli" alla cieca; se falliscono per le nuove fixtures causali o per la rinomina "saggi", correggi il test.

**Step 4: Riepilogo finale.** Elenca i file toccati (per il commit manuale di Paolo) e gli esiti dei test. NON committare.
