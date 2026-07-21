# Card-filtro analytics (giacenze + documenti) — Implementation Plan (Fase 2)

> **For Claude:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.
> **IMPORTANTE:** NON committare mai — Paolo committa a mano. Comandi Rails nel container: `docker exec prova-app-1 bin/rails ...` (senza -it).
> Design: `docs/plans/2026-07-21-giacenze-conteggi-design.md`, sezione "Fase 2" (leggerla prima).

**Goal:** Card analytics cliccabili che filtrano server-side e sincronizzano righe + pannello filtri, layout uniforme (card → filtri → risultati) su giacenze e documenti.

**Architecture:** Partial condiviso `shared/_analytics_filter_cards.html.erb` con link full-page (`turbo_action: advance`, nessun frame). Numeri card calcolati ignorando lo stato (pattern `stato_counts`). Giacenze: STATI completo (7 voci) e `libri(ignora_stato:)`. Documenti: pills `_stato_tabs` sostituite dalle card fuori dal frame. Propaganda NON si tocca (usa ancora `doc-stato-tab*`, il CSS resta).

---

### Task A: Partial condiviso + CSS + giacenze

**Files:**
- Create: `app/views/shared/_analytics_filter_cards.html.erb`
- Modify: `app/assets/stylesheets/analytics.css`
- Modify: `app/models/filters/giacenza_filter.rb`
- Modify: `app/controllers/giacenze_controller.rb`
- Modify: `app/views/giacenze/index.html.erb`
- Modify: `test/models/filters/giacenza_filter_test.rb` (stati nuovi)
- Modify: `test/controllers/giacenze_controller_test.rb`

**Step 1: Partial condiviso** `app/views/shared/_analytics_filter_cards.html.erb`:

```erb
<%# locals: (cards:, current:, url:, param:) -%>
<%# Card KPI che filtrano server-side: ogni card con key è un link full-page
    (aggiorna righe, card e pannello filtri insieme); la card attiva linka
    l'URL senza il param (toggle off). key nil = KPI non cliccabile. %>
<% base_params = request.query_parameters.except("page", param.to_s) %>

<div class="analytics-summary">
  <% cards.each do |card| %>
    <% if card[:key] %>
      <% active = current == card[:key] %>
      <%= link_to url_for(url) + "?" + base_params.merge(active ? {} : { param => card[:key] }).compact_blank.to_query,
            class: class_names("analytics-summary__card", "analytics-summary__card--link",
                               "analytics-summary__card--active": active),
            aria: { pressed: active },
            data: { turbo_action: "advance" } do %>
        <p class="analytics-summary__value <%= card[:value_class] %>"><%= card[:value] %></p>
        <p class="analytics-summary__label"><%= card[:label] %></p>
      <% end %>
    <% else %>
      <div class="analytics-summary__card">
        <p class="analytics-summary__value <%= card[:value_class] %>"><%= card[:value] %></p>
        <p class="analytics-summary__label"><%= card[:label] %></p>
      </div>
    <% end %>
  <% end %>
</div>
```

Nota URL: costruiscilo in modo pulito — se `base_params.merge(...)` è vuoto niente "?" penzolante. Puoi usare `url_for(params: ...)`? NO: usa la forma semplice `"#{url}?#{query}"` con guard su query vuota, oppure `url_for(request.query_parameters.except("page", param.to_s).merge(...).merge(only_path: true))` se funziona col routing — scegli la forma più semplice che passa i test. `card[:value]` arriva già formattato (numero o €).

**Step 2: CSS** in `analytics.css`, accanto alle regole `.analytics-summary__card` esistenti (guarda le righe 70-89: le regole `.ca-page ...` NON si toccano). Aggiungi la variante generica:

```css
  .analytics-summary__card--link {
    color: inherit;
    cursor: pointer;
    display: block;
    text-decoration: none;
  }

  .analytics-summary__card--link:hover {
    background-color: var(--color-ink-lighter);
    outline-color: color-mix(in oklch, var(--color-link) 45%, transparent);
  }

  .analytics-summary__card--link:focus-visible {
    outline-color: var(--color-link);
  }

  .analytics-summary__card--link.analytics-summary__card--active {
    background-color: color-mix(in oklch, var(--color-link) 8%, transparent);
    outline-color: var(--color-link);
  }
```

(la card base ha già `outline: 2px solid transparent` + transition.)

**Step 3: `GiacenzaFilter`** — STATI completo e `ignora_stato`:

```ruby
STATI = {
  "adottati"      => "Adottati",
  "campionario"   => "In campionario",
  "saggi_100"     => "Saggi 100",
  "saggi_50"      => "Saggi 50",
  "scarico_saggi" => "Scarico saggi",
  "venduti"       => "Venduti",
  "impegnati"     => "Da consegnare"
}.freeze

def libri(ignora_stato: false)
  ...identico a oggi, ma il case stato è saltato se ignora_stato...
end
```

Aggiungi i tre rami nuovi nel case: `saggi_100`/`saggi_50`/`scarico_saggi` → `COALESCE(conteggi.<col>, 0) > 0`. ATTENZIONE ad `alias_method :results, :libri`: verifica che `results` continui a funzionare senza argomenti (i chiamanti esterni non passano nulla — ok con default). Occhio anche a chi chiama `filter.libri` senza parentesi: nessun cambiamento di firma breaking.

**Step 4: Controller** — totali dallo scope senza stato:

```ruby
scope = @filter.libri.includes(:editore)
scope_totali = @filter.libri(ignora_stato: true)

@totali = totali(scope_totali)
@total_count = scope.except(:select).count
```

(`totali` già fa `except(:select).pick(...)`; niente più `.except(:includes, :order)` sul primo scope — passa direttamente `scope_totali`, che non ha includes; verifica che l'ordinamento non disturbi `pick`, altrimenti aggiungi `.reorder(nil)`.)

**Step 5: `index.html.erb`** — sostituisci il blocco `analytics-summary` con il partial condiviso:

```erb
<%= render "shared/analytics_filter_cards",
      url: giacenze_path,
      param: :stato,
      current: @filter.stato,
      cards: [
        { key: "adottati",      value: number_with_delimiter(@totali.fetch(:adottati)),      label: "adottati" },
        { key: "campionario",   value: number_with_delimiter(@totali.fetch(:campionario)),   label: "campionario" },
        { key: "scarico_saggi", value: number_with_delimiter(@totali.fetch(:scarico_saggi)), label: "scarico saggi" },
        { key: "venduti",       value: number_with_delimiter(@totali.fetch(:venduti)),       label: "vendute", value_class: "txt-positive" },
        { key: "impegnati",     value: number_with_delimiter(@totali.fetch(:da_consegnare)), label: "da consegnare" },
        { key: nil,             value: number_to_currency(@totali.fetch(:venduto_cents) / 100.0, locale: :it), label: "venduto", value_class: "txt-positive" }
      ] %>
```

Le card sono GIÀ sopra `filters/settings` in giacenze: layout ok, non spostare altro.

**Step 6: Test.**
- `giacenza_filter_test.rb`: aggiungi test per i 3 stati nuovi (saggi_100/saggi_50/scarico_saggi con documenti delle rispettive causali — la fixture :saggi_100 ecc. esiste) e per `libri(ignora_stato: true)` che ignora lo stato ma rispetta editori/anno.
- `giacenze_controller_test.rb`: (a) i totali card NON cambiano quando `stato` è attivo (stesso valore campionario con e senza `stato: "venduti"`); (b) markup: card attiva `.analytics-summary__card--active` presente con `stato: "campionario"`, e il suo `href` NON contiene `stato=` (toggle); una card non attiva ha `href` con `stato=`; (c) card venduto € non è un link; (d) stato `saggi_100` filtra.

**Step 7:**
```
docker exec prova-app-1 bin/rails test test/models/filters/giacenza_filter_test.rb test/controllers/giacenze_controller_test.rb
```
Atteso PASS. NON committare.

---

### Task B: Documenti — card al posto delle pills

**Files:**
- Delete: `app/views/documenti/_stato_tabs.html.erb`
- Modify: `app/views/documenti/index.html.erb`
- Modify: `test/controllers/documenti_controller_test.rb`
- NON toccare: `app/views/propaganda/**` e il CSS `doc-stato-tab*` (usato da propaganda).

**Step 1: `index.html.erb`** — rimuovi `<%= render "documenti/stato_tabs", ... %>` da dentro il frame `search_results`; sopra `<%= render "filters/settings", ... %>` aggiungi:

```erb
<%= render "shared/analytics_filter_cards",
      url: documenti_path,
      param: :stato_documento,
      current: @filter.stato_documento.presence || "attivi",
      cards: [
        { key: "tutti",         value: @stato_counts["tutti"],         label: "tutti" },
        { key: "attivi",        value: @stato_counts["attivi"],        label: "attivi" },
        { key: "da_consegnare", value: @stato_counts["da_consegnare"], label: "da consegnare" },
        { key: "da_pagare",     value: @stato_counts["da_pagare"],     label: "da pagare" },
        { key: "completati",    value: @stato_counts["completati"],    label: "completati", value_class: "txt-positive" }
      ] %>
```

Verifica dove sta il `content_for :header` e il blocco hotwire_native: le card vanno nel body della pagina, prima di filters/settings. Elimina `_stato_tabs.html.erb`.

NOTA toggle: la card attiva linka l'URL senza `stato_documento` → il filter torna al default "attivi" (il current di default è "attivi", quindi la card "attivi" risulta attiva quando il param manca — coerente).

**Step 2: Test** `documenti_controller_test.rb`: sostituisci le asserzioni `.doc-stato-tabs`/`.doc-stato-tab--active` con le equivalenti sulle card: presenza `.analytics-summary`, card attiva `.analytics-summary__card--active` con label giusta ("attivi" di default, "completati" con `stato_documento: "completati"`). Mantieni la sostanza dei test esistenti (filtri per stato, counts).

**Step 3:**
```
docker exec prova-app-1 bin/rails test test/controllers/documenti_controller_test.rb test/controllers/propaganda_controller_test.rb
```
Atteso PASS (propaganda intatta).

**Step 4: Suite completa**
```
docker exec prova-app-1 bin/rails test
```
Atteso PASS. Riepilogo file toccati per il commit manuale. NON committare.
