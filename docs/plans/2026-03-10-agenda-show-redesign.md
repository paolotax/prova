# Agenda Show Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ripulire la agenda/show: eliminare DropdownComponent, riorganizzare header, aggiungere pulsanti laterali alla lista tappe, bulk_bar sulle entries, rimuovere mappa inline.

**Architecture:** Header semplificato con "Settimana" a sinistra e date picker a destra. Pulsanti azione (Ricalcola, Mappa, Stampe) ai lati della lista tappe su desktop, sopra su mobile. Entries con bulk_bar selezionabile. Mappa come pagina separata.

**Tech Stack:** Rails 8.1, Turbo, Stimulus, CSS Fizzy utilities

---

### Task 1: Riorganizzare l'header

**Files:**
- Modify: `app/views/agenda/show.erb` (righe 11-109)

**Step 1: Sostituire l'header attuale**

Rimpiazzare tutto il blocco `content_for :header` con:

```erb
<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <%= link_to agenda_path(giorno: @giorno), class: "btn btn--back",
        data: { controller: "link-modifier hotkey tooltip",
                link_modifier_target: "link",
                action: "keydown.w@document->hotkey#click" } do %>
      <%= icon_tag "calendar" %>
      <strong class="overflow-ellipsis">Settimana</strong>
      <kbd class="kbd txt-x-small hide-on-touch">W</kbd>
    <% end %>
  </div>

  <div class="header__title divider divider--fade full-width">
    <%= link_to giorno_path(giorno: (@giorno - 1.day).to_s),
        class: "btn txt-x-small",
        data: { controller: "link-modifier tooltip hotkey",
                link_modifier_target: "link",
                action: "keydown.left@document->hotkey#click" } do %>
      <%= icon_tag "arrow-left", size: "small" %>
      <span class="for-screen-reader">Giorno precedente <kbd class="kbd">&larr;</kbd></span>
    <% end %>

    <span class="overflow-ellipsis"><%= I18n.l(@giorno.to_date, format: :long_with_day, locale: :it) %></span>

    <%= link_to giorno_path(giorno: (@giorno + 1.day).to_s),
        class: "btn txt-x-small",
        data: { controller: "link-modifier tooltip hotkey",
                link_modifier_target: "link",
                action: "keydown.right@document->hotkey#click" } do %>
      <%= icon_tag "arrow-right", size: "small" %>
      <span class="for-screen-reader">Giorno successivo <kbd class="kbd">&rarr;</kbd></span>
    <% end %>
  </div>

  <div class="header__actions header__actions--end">
    <div data-controller="date-selector"
         data-date-selector-base-path-value="<%= giorno_path(giorno: '__DATE__').sub('__DATE__', '') %>">
      <input type="date" value="<%= @giorno %>"
             data-date-selector-target="picker"
             data-action="change->date-selector#change"
             class="input--hidden">
      <button type="button" class="btn btn--circle"
              data-action="date-selector#open">
        <%= icon_tag "calendar", size: "small" %>
        <span class="for-screen-reader">Scegli data</span>
      </button>
    </div>
  </div>
<% end %>
```

**Step 2: Rimuovere i JS Mapbox dall'header**

Eliminare il blocco `content_for :head` (righe 3-9) con i javascript/stylesheet di Mapbox. Servono solo nella pagina mappa.

**Step 3: Commit**

```bash
git add app/views/agenda/show.erb
git commit -m "feat: agenda header con Settimana, frecce, date picker"
```

---

### Task 2: Pulsanti laterali alla lista tappe

**Files:**
- Modify: `app/views/agenda/show.erb` (sezione tappe)
- Possibly create: `app/views/agenda/_tappe_actions.html.erb`

**Step 1: Creare il layout con pulsanti ai lati**

Sostituire la section tappe con un layout flex a 3 colonne su desktop. Su mobile i pulsanti vanno sopra.

```erb
<%# Pulsanti azione tappe — mobile: sopra, desktop: ai lati %>
<% if @tappe.any? %>
  <div class="agenda-day__actions hide-on-desktop flex gap-half justify-center margin-block-end-half">
    <% if @tappe.size > 1 %>
      <%= link_to url_for(controller: "mappe", action: "calcola_percorso_ottimale", method: :get, params: { giorno: @giorno.to_s }),
          class: "btn btn--circle", data: { controller: "tooltip" } do %>
        <%= icon_tag "arrows-pointing-out", size: "small" %>
        <span class="for-screen-reader">Ricalcola percorso</span>
      <% end %>
    <% end %>

    <%= link_to mappa_del_giorno_path(@giorno),
        class: "btn btn--circle", data: { controller: "tooltip" } do %>
      <%= icon_tag "map", size: "small" %>
      <span class="for-screen-reader">Mappa</span>
    <% end %>

    <div style="position: relative"
         data-controller="dialog"
         data-action="keydown.esc->dialog#close click@document->dialog#closeOnClickOutside">
      <button type="button" class="btn btn--circle" data-action="dialog#toggle" data-controller="tooltip">
        <%= icon_tag "printer", size: "small" %>
        <span class="for-screen-reader">Stampe</span>
      </button>
      <dialog class="popup panel fill-white shadow txt-small" data-dialog-target="dialog">
        <ul class="popup__list">
          <li class="popup__item">
            <%= link_to tappe_giorno_pdf_path(giorno: @giorno), class: "popup__btn btn",
                data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
              Elenco tappe del giorno
            <% end %>
          </li>
          <li class="popup__item">
            <%= link_to adozioni_tappe_pdf_path(giorno: @giorno), class: "popup__btn btn",
                data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
              Kit adozioni nel baule
            <% end %>
          </li>
          <li class="popup__item">
            <%= link_to dettaglio_appunti_documenti_pdf_path(giorno: @giorno), class: "popup__btn btn",
                data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
              Dettaglio appunti e documenti
            <% end %>
          </li>
          <li class="popup__item">
            <%= link_to fogli_scuola_tappe_pdf_path(giorno: @giorno, tipo_stampa: 'mie_adozioni'), class: "popup__btn btn",
                data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
              Fogli scuola
            <% end %>
          </li>
          <li class="popup__item">
            <%= link_to fogli_scuola_tappe_pdf_path(giorno: @giorno, tipo_stampa: 'mie_adozioni', con_sovrapacchi: true), class: "popup__btn btn",
                data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
              Fogli scuola + sovrapacchi
            <% end %>
          </li>
        </ul>
      </dialog>
    </div>
  </div>
<% end %>
```

**Step 2: Layout desktop a 3 colonne**

Wrappare lista tappe + pulsanti laterali:

```erb
<div class="agenda-day" data-controller="bulk-actions swipe"
     data-swipe-left-value="<%= giorno_path(giorno: (@giorno - 1.day).to_s) %>"
     data-swipe-right-value="<%= giorno_path(giorno: (@giorno + 1.day).to_s) %>"
     style="min-block-size: calc(100dvh - 8rem);">

  <div class="agenda-day__layout">
    <%# Sinistra — desktop only %>
    <div class="agenda-day__side agenda-day__side--start hide-on-touch">
      <% if @tappe.size > 1 %>
        <%= link_to url_for(controller: "mappe", action: "calcola_percorso_ottimale", method: :get, params: { giorno: @giorno.to_s }),
            class: "btn btn--circle", data: { controller: "tooltip" } do %>
          <%= icon_tag "arrows-pointing-out", size: "small" %>
          <span class="for-screen-reader">Ricalcola percorso</span>
        <% end %>
      <% end %>

      <%= link_to mappa_del_giorno_path(@giorno),
          class: "btn btn--circle", data: { controller: "tooltip" } do %>
        <%= icon_tag "map", size: "small" %>
        <span class="for-screen-reader">Mappa</span>
      <% end %>
    </div>

    <%# Centro — lista tappe %>
    <section class="cards is-expanded" style="--card-color: oklch(var(--lch-blue-medium)); --cards-gap: 0.6rem; inline-size: 100%; max-inline-size: var(--column-width-expanded, 450px); container-type: inline-size;">
      <div class="board-tools card" style="flex-wrap: wrap;">
        <%= link_to new_documento_path, class: "btn btn--link", data: { turbo_frame: "_top" } do %>
          <%= icon_tag "document" %>
          <span>Documento</span>
          <kbd class="hide-on-touch">D</kbd>
        <% end %>

        <%= link_to new_appunto_path, class: "btn btn--link", data: { turbo_frame: "_top" } do %>
          <%= icon_tag "note" %>
          <span>Appunto</span>
          <kbd class="hide-on-touch">A</kbd>
        <% end %>

        <div style="flex-basis: 100%; text-align: center;">
          <%= link_to new_tappa_path(data_tappa: @giorno), class: "btn btn--link", data: { turbo_frame: "_top" } do %>
            <%= icon_tag "add", size: "small" %>
            <span>Tappa</span>
          <% end %>
        </div>
      </div>

      <div class="cards__transition-container">
        <div id="giorno-<%= @giorno %>"
            class="cards__list"
            data-controller="tax-sortable"
            data-tax-sortable-group-value="calendar"
            data-tax-sortable-data-tappa="<%= @giorno.to_s %>"
            data-action="dragstart->tax-sortable#dragStart dragover->tax-sortable#dragOver dragenter->tax-sortable#dragEnter dragleave->tax-sortable#dragLeave drop->tax-sortable#drop dragend->tax-sortable#dragEnd">
            <%= render partial: "tappe/tappa", collection: @tappe, as: :tappa %>
        </div>
      </div>
    </section>

    <%# Destra — desktop only %>
    <div class="agenda-day__side agenda-day__side--end hide-on-touch">
      <%# Popup stampe — stesso markup del mobile %>
      <div style="position: relative"
           data-controller="dialog"
           data-action="keydown.esc->dialog#close click@document->dialog#closeOnClickOutside">
        <button type="button" class="btn btn--circle" data-action="dialog#toggle" data-controller="tooltip">
          <%= icon_tag "printer", size: "small" %>
          <span class="for-screen-reader">Stampe</span>
        </button>
        <dialog class="popup panel fill-white shadow txt-small" data-dialog-target="dialog">
          <ul class="popup__list">
            <li class="popup__item">
              <%= link_to tappe_giorno_pdf_path(giorno: @giorno), class: "popup__btn btn",
                  data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
                Elenco tappe del giorno
              <% end %>
            </li>
            <li class="popup__item">
              <%= link_to adozioni_tappe_pdf_path(giorno: @giorno), class: "popup__btn btn",
                  data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
                Kit adozioni nel baule
              <% end %>
            </li>
            <li class="popup__item">
              <%= link_to dettaglio_appunti_documenti_pdf_path(giorno: @giorno), class: "popup__btn btn",
                  data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
                Dettaglio appunti e documenti
              <% end %>
            </li>
            <li class="popup__item">
              <%= link_to fogli_scuola_tappe_pdf_path(giorno: @giorno, tipo_stampa: 'mie_adozioni'), class: "popup__btn btn",
                  data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
                Fogli scuola
              <% end %>
            </li>
            <li class="popup__item">
              <%= link_to fogli_scuola_tappe_pdf_path(giorno: @giorno, tipo_stampa: 'mie_adozioni', con_sovrapacchi: true), class: "popup__btn btn",
                  data: { controller: "link-modifier", link_modifier_target: "link", action: "click->dialog#close" } do %>
                Fogli scuola + sovrapacchi
              <% end %>
            </li>
          </ul>
        </dialog>
      </div>
    </div>
  </div>

  <% if @tappe.empty? %>
    <div class="blank-slate blank-slate--empty" style="margin-inline: auto; text-align: center;">
      <h3 class="txt-large font-weight-bold">Nessuna tappa in programma</h3>
      <p class="txt-small txt-subtle margin-block-end">Aggiungi una tappa per iniziare.</p>
    </div>
  <% end %>

  <%= render "tappe/bulk_bar/bar" %>
</div>
```

**Step 3: Aggiungere CSS per il layout a 3 colonne**

Creare stili in un file CSS appropriato (es. `agenda.css` o `utilities.css`):

```css
.agenda-day__layout {
  display: flex;
  align-items: flex-start;
  justify-content: center;
  gap: var(--inline-space);
}

.agenda-day__side {
  display: flex;
  flex-direction: column;
  gap: var(--block-space-half);
  padding-block-start: 4rem; /* allinea coi primi items della lista */
  position: sticky;
  top: 4rem;
}
```

**Step 4: Commit**

```bash
git add app/views/agenda/show.erb app/assets/stylesheets/
git commit -m "feat: pulsanti laterali tappe con popup stampe (sostituisce DropdownComponent)"
```

---

### Task 3: Rimuovere mappa inline e JS Mapbox

**Files:**
- Modify: `app/views/agenda/show.erb`

**Step 1: Rimuovere il turbo frame mappa in fondo alla pagina**

Eliminare:

```erb
<% if @tappe.any? %>
  <%= turbo_frame_tag :mappa, src: mappa_del_giorno_path(@giorno), data: { turbo_cache: false }, loading: :lazy %>
<% end %>
```

E il div vuoto:

```erb
<div class="margin-block-start-double"></div>
```

**Step 2: Verificare che la pagina mappa funzioni standalone**

La action `mappa` nel controller e il template `agenda/mappa.html.erb` esistono già. Verificare che la pagina mappa carichi i JS Mapbox nel suo layout o con `content_for :head`. Se no, spostare il blocco Mapbox JS lì.

**Step 3: Commit**

```bash
git add app/views/agenda/
git commit -m "chore: rimuovi mappa inline, ora accessibile via pulsante Mappa"
```

---

### Task 4: Bulk bar sulla sezione entries

**Files:**
- Modify: `app/views/agenda/show.erb` (sezione entries)
- Possibly create: `app/views/agenda/_entries_bulk_bar.html.erb`

**Step 1: Verificare il pattern bulk_bar in open_entries**

Guardare come funziona in `app/views/entries/open_entries/` o `app/views/scuole/` per capire il pattern con `bulk-actions` controller e checkbox di selezione.

**Step 2: Wrappare la sezione entries con bulk-actions controller**

```erb
<% if @entries_per_tappa&.any? %>
  <div class="full-width pad group" data-controller="bulk-actions">
    <%= render "agenda/entries_bulk_bar" %>

    <% @entries_per_tappa.each do |tappa, entries| %>
      <%# Filtra tappe — si vedono già nella lista sopra %>
      <% filtered_entries = entries.reject { |e| e.entryable_type == "Tappa" } %>
      <% next if filtered_entries.empty? %>

      <h3 class="divider divider--fade txt-medium font-weight-black">
        <%= tappa.tappable.denominazione %> (<%= filtered_entries.count %>)
      </h3>
      <div class="cards cards--grid cards--in-context">
        <div class="cards__list">
          <% filtered_entries.each do |entry| %>
            <%= render "entries/entry", entry: entry, draggable: false %>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

**Step 3: Creare il partial bulk_bar per agenda entries**

Seguire il pattern di `entries/bulk_bar/_bar.html.erb` adattato per le entries del giorno. I pulsanti bulk dipendono da cosa l'utente vuole fare (stampa, sposta, chiudi). Per ora implementare con almeno il pulsante "Seleziona" per mobile e "Seleziona tutti".

**Step 4: Commit**

```bash
git add app/views/agenda/
git commit -m "feat: bulk_bar selezionabile sulla sezione entries del giorno"
```

---

### Task 5: Escludere tappe dalla lista entries

**Files:**
- Modify: `app/controllers/agenda_controller.rb` (metodo `load_giorno_entries`)

**Step 1: Verificare come vengono caricate le entries**

```ruby
# Trovare il metodo load_giorno_entries e filtrare le tappe
```

**Step 2: Escludere entryable_type Tappa**

Nel metodo che carica `@entries_per_tappa`, aggiungere `.where.not(entryable_type: "Tappa")` alla query delle entries.

**Step 3: Commit**

```bash
git add app/controllers/agenda_controller.rb
git commit -m "fix: escludi tappe dalla lista entries del giorno (già visibili sopra)"
```

---

## Execution Order

1. Task 1: Header (Settimana, frecce, date picker)
2. Task 2: Pulsanti laterali + popup stampe (elimina DropdownComponent)
3. Task 3: Rimuovi mappa inline + JS Mapbox
4. Task 4: Bulk bar entries
5. Task 5: Escludi tappe da entries

## Note

- Il `DropdownComponent` (ViewComponent deprecato) viene sostituito dal pattern popup dialog nativo come in giri/show
- La mappa resta accessibile come pagina separata via `mappa_del_giorno_path`
- I JS Mapbox vanno spostati nel template `mappa.html.erb` se non sono già lì
- La bulk_bar usa lo stesso pattern di `open_entries` con `bulk-actions` controller
- `hide-on-touch` e `hide-on-desktop` sono utility CSS esistenti (verificare che esistano, altrimenti usare media query)
