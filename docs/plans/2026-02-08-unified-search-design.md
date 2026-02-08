# Unified Search — Command Palette per navigazione entita'

## Obiettivo

Sostituire i sistemi di ricerca legacy (SearchController morto, CommandMenu::ItemComponent inesistente, bar_controller.js mancante, _search_form.html.erb inutilizzata) con un'unica search globale attivata dalla bar in basso.

L'utente preme K (o clicca "Cerca"), si apre un popup con un campo di ricerca. Digitando, i risultati appaiono raggruppati per tipo di entita', navigabili con frecce e Enter. Il contesto della pagina corrente determina quale tipo appare per primo.

Non e' una ricerca testuale full-text (come Fizzy con FTS5). E' una **ricerca per entita'/navigazione** — trova scuole, libri, clienti, documenti, appunti, ecc. per andarci.

---

## 1. Pulizia codice morto

### Eliminare

| File | Motivo |
|------|--------|
| `app/controllers/search_controller.rb` | Riscritto da zero |
| `app/views/search/index.turbo_stream.erb` | Referenzia CommandMenu::ItemComponent inesistente |
| `app/views/searches/_form.html.erb` | Era di Fizzy ("Search Fizzy"), non serve |
| `app/views/layouts/_search_form.html.erb` | Non inclusa in nessun layout attivo (solo in `_main_menu.html_old.erb`) |

### Tenere e trasformare

| File | Azione |
|------|--------|
| `app/views/layouts/_bar.html.erb` | Riscrivere come trigger della nuova search |
| `app/assets/stylesheets/bar.css` | Tenere, aggiungere CSS per il popup search |

### Non serve

- `bar_controller.js` di Fizzy — il popup usa `dialog_controller` + `form_controller` + `navigable-list` gia' esistenti

---

## 2. UI — Popup di ricerca dalla bar

### Layout visivo

```
┌──────────────────────────────────────┐
│ [input search field]           [Esc] │
├──────────────────────────────────────┤
│ ▸ Libri (contesto pagina corrente)   │
│   ┊ Matematica per la 3a - Zanich.   │
│   ┊ Italiano facile - Mondadori      │
│ ▸ Scuole                             │
│   ┊ IC Dante Alighieri - Roma        │
│ ▸ Clienti                            │
│   ┊ Libreria Moderna - Milano        │
│ ▸ Appunti                            │
│   ┊ Ordine INVALSI per IC Dante      │
│                                      │
│  (sezioni vuote nascoste)            │
└──────────────────────────────────────┘
            [ Cerca K ]  ← bar fissa in basso
```

### Struttura HTML (`_bar.html.erb`)

```erb
<div class="bar" data-controller="dialog"
     data-action="keydown.esc->dialog#close click@document->dialog#closeOnClickOutside">

  <!-- Bottone trigger -->
  <div class="bar__placeholder">
    <button class="btn btn--plain" type="button"
            data-controller="hotkey"
            data-action="click->dialog#toggle keydown.k@document->hotkey#click">
      Cerca <kbd class="hide-on-touch">K</kbd>
    </button>
  </div>

  <!-- Popup search -->
  <dialog class="bar__search popup popup--animated panel"
          data-dialog-target="dialog"
          data-controller="navigable-list"
          data-navigable-list-actionable-items-value="true">

    <!-- Input -->
    <div class="bar__search-header">
      <form action="/search" method="get" data-controller="form"
            data-turbo-frame="search_results">
        <input type="hidden" name="context" value="<%= controller_name %>">
        <input type="search" name="q" placeholder="Cerca..."
               class="input input--transparent txt-small"
               autocomplete="off" autofocus
               data-navigable-list-target="input"
               data-action="input->form#debouncedSubmit">
      </form>
    </div>

    <!-- Risultati -->
    <div class="nav__scroll-container">
      <turbo-frame id="search_results" target="_top">
      </turbo-frame>
      <div class="nav__blank-slate blank-slate blank-slate--empty">
        Nessun risultato
      </div>
    </div>
  </dialog>
</div>
```

### Controller Stimulus riusati

| Controller | Ruolo |
|------------|-------|
| `dialog` | Apre/chiude il popup, gestisce Esc e click outside |
| `hotkey` | K apre la ricerca |
| `navigable-list` | Frecce su/giu tra i risultati, Enter clicca il link |
| `form` | `debouncedSubmit` sull'input (300ms) |

**Nessun nuovo controller JS da scrivere.**

### CSS da aggiungere (`bar.css`)

```css
.bar__search.popup {
  inset: auto 0 calc(var(--footer-height) + env(safe-area-inset-bottom)) 0;
  max-block-size: 70dvh;
  margin: 0;
  inline-size: 100%;
  max-inline-size: min(55ch, 100vw);
  margin-inline: auto;
}
```

---

## 3. Backend — SearchController con registry

### Controller

```ruby
class SearchController < ApplicationController
  SEARCHABLES = {
    scuole:    { search: :search_all_word, label: "Scuole",    icon: "building-library" },
    libri:     { search: :search_all_word, label: "Libri",     icon: "book" },
    clienti:   { search: :left_search,     label: "Clienti",   icon: "users" },
    documenti: { search: :search_docs,     label: "Documenti", icon: "document" },
    appunti:   { search: :search_all_word, label: "Appunti",   icon: "note" },
    classi:    { search: :search_all_word, label: "Classi",    icon: "academic-cap" },
    persone:   { search: :ilike_search,    label: "Persone",   icon: "user" },
  }

  FIXED_ORDER = %i[scuole libri clienti documenti appunti classi persone].freeze

  def index
    return head(:no_content) if params[:q].blank? || params[:q].length < 2

    @results = ordered_keys.filter_map do |key|
      config = SEARCHABLES[key]
      records = Current.account.public_send(key)
                  .public_send(config[:search], params[:q])
                  .limit(6)
      next if records.empty?

      { key:, records:, **config }
    end
  end

  private

  def ordered_keys
    context = params[:context]&.to_sym
    return FIXED_ORDER unless context && SEARCHABLES.key?(context)

    [context] + (FIXED_ORDER - [context])
  end
end
```

### Meccanismi di ricerca per entita'

| Entita' | Metodo | Gia' esiste? |
|---------|--------|--------------|
| Scuola | `search_all_word` (PgSearch) | Si |
| Libro | `search_all_word` (PgSearch) | Si |
| Cliente | `left_search` (Searchable ILIKE) | Si |
| Documento | `search_docs` (LEFT JOIN scuole/clienti/causali) | Estrarre da DocumentoFilterProxy |
| Appunto | `search_all_word` (PgSearch) | Si |
| Classe | `search_all_word` (custom scope) | Si |
| Persona | `ilike_search` (cognome/nome ILIKE) | Da creare (semplice scope) |

### Entita' future

Aggiungere una riga al hash:

```ruby
adozioni: { search: :search_all_word, label: "Adozioni", icon: "cash" },
tappe:    { search: :search_all_word, label: "Tappe",    icon: "map-pin" },
```

---

## 4. Risultati — rendering e navigazione

### View `search/index.html.erb`

```erb
<%= turbo_frame_tag "search_results" do %>
  <% @results&.each do |group| %>
    <details class="popup__section" open>
      <summary class="popup__section-title">
        <%= icon_tag "caret-down" %><%= group[:label] %>
      </summary>
      <ul class="popup__list">
        <% group[:records].each do |record| %>
          <li class="popup__item"
              data-navigable-list-target="item">
            <%= icon_tag group[:icon], class: "popup__icon" %>
            <%= link_to search_result_path(record),
                  class: "popup__btn btn",
                  data: { turbo_frame: "_top" } do %>
              <span class="overflow-ellipsis"><%= search_result_label(record) %></span>
            <% end %>
          </li>
        <% end %>
      </ul>
    </details>
  <% end %>
<% end %>
```

### Helper `search_helper.rb`

```ruby
module SearchHelper
  def search_result_path(record)
    case record
    when Scuola    then scuola_path(Current.account, record)
    when Libro     then libro_path(Current.account, record)
    when Cliente   then cliente_path(Current.account, record)
    when Documento then documento_path(Current.account, record)
    when Appunto   then appunto_path(Current.account, record)
    when Classe    then classe_path(Current.account, record)
    when Persona   then persona_path(Current.account, record)
    end
  end

  def search_result_label(record)
    case record
    when Scuola    then "#{record.denominazione} - #{record.comune}"
    when Libro     then "#{record.titolo} - #{record.editore&.editore}"
    when Cliente   then "#{record.denominazione} - #{record.comune}"
    when Documento then "#{record.numero_documento} - #{record.causale&.causale}"
    when Appunto   then record.nome
    when Classe    then "#{record.to_s} - #{record.scuola&.denominazione}"
    when Persona   then "#{record.cognome} #{record.nome}"
    end
  end
end
```

### Navigazione tastiera

- **Frecce su/giu**: `navigable-list` gestisce selezione visiva tra gli `[data-navigable-list-target="item"]`
- **Enter**: con `actionable_items: true` clicca il link dentro l'item selezionato
- **Esc**: `dialog#close` chiude il popup
- **Click su risultato**: naviga alla pagina + `turbo:before-cache` chiude il dialog (come il menu)

### Blank slate

Visibile solo quando il turbo-frame e' vuoto. Il CSS `:has()` del menu lo gestisce gia':

```css
.nav__scroll-container:has(#search_results:empty) .blank-slate--empty { display: flex; }
.nav__scroll-container:not(:has(#search_results:empty)) .blank-slate--empty { display: none; }
```

---

## 5. Route

```ruby
resources :search, only: [:index], controller: "search"
```

---

## 6. Riepilogo file

### Da creare

| File | Contenuto |
|------|-----------|
| `app/controllers/search_controller.rb` | Controller con registry SEARCHABLES |
| `app/views/search/index.html.erb` | Turbo frame con sezioni raggruppate |
| `app/helpers/search_helper.rb` | `search_result_path` + `search_result_label` |

### Da modificare

| File | Modifica |
|------|----------|
| `app/views/layouts/_bar.html.erb` | Riscrivere con dialog + popup |
| `app/assets/stylesheets/bar.css` | Aggiungere `.bar__search.popup` |
| `app/models/documento.rb` | Estrarre scope `search_docs` da DocumentoFilterProxy |
| `app/models/persona.rb` | Aggiungere scope `ilike_search` |
| `config/routes.rb` | Aggiungere route search |

### Da eliminare

| File | Motivo |
|------|--------|
| `app/views/search/index.turbo_stream.erb` | Referenzia componenti inesistenti |
| `app/views/searches/_form.html.erb` | Era di Fizzy |
| `app/views/layouts/_search_form.html.erb` | Non usata da nessun layout attivo |

---

## 7. Cosa NON cambia

- **Filter settings** (`_settings.html.erb` + `terms[]`): resta per il filtraggio in-page sugli index
- **DestinatariController**: resta per la combobox selezione destinatario appunti
- **PgSearch e Searchable** sui modelli: riusati cosi' come sono
- **Nessun nuovo controller Stimulus**: tutto fatto con controller esistenti
