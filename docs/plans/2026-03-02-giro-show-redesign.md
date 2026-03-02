# Giro Show Page Redesign

## Problema

La show page del giro (kanban a 3 colonne con `GroupByDateService`) è confusa e il workflow di creazione tappe non funziona bene. Il "genera tappe" è troppo grezzo (prende tutte le elementari), i filtri tab sono ridondanti, e l'esperienza è incoerente con l'agenda.

## Concetto di Giro

Un giro è un'esecuzione concreta: "Consegna Collane Marzo 2026". Ha un periodo (`iniziato_il` → `finito_il`), un set di scuole, e delle tappe da programmare nei giorni. Tipi di giro: consegna collane, ritiro collane, consegna compiti vacanze, kit adozioni, consegna pacchetti, pattugliamento zona (es. "Giro Ferrara SUD"). Un giro può essere copiato anno dopo anno.

Il modello dati attuale (Giro, Tappa, TappaGiro many-to-many) resta valido. Una tappa può far parte di più giri.

---

## Design

### Layout show page

Due elementi principali, riusa componenti CSS dall'agenda (`agenda-calendar.css`):

**Planner** — pannello sticky in alto, toggle con tasto P. Mostra le tappe del giro senza data (`data_tappa IS NULL`), raggruppate per area e direzione. Drag & drop verso la griglia per assegnare una data. Drop dalla griglia al planner per de-programmare. Trash zone per eliminare tappe. Stessa animazione open/close dell'agenda.

**Griglia settimanale compatta** — mostra SOLO le settimane tra `iniziato_il` e `finito_il` del giro. Niente scroll infinito, niente sentinel. Stessi componenti: `agenda-week`, `agenda-week__day`, `tappa-compact`. Mostra solo le tappe del giro corrente. Drag & drop tra giorni con SortableJS + sort endpoint.

**Header** — titolo giro con pallino colore, pulsante Planner con kbd P, pulsante edit (apre dialog), menu dropdown con: "Genera tappe", "Copia da giro", "Elimina giro".

### Genera tappe

Dialog modale attivata dal dropdown azioni:

- Filtri preimpostati dal campo `conditions` del giro (provincia, tipo scuola, area)
- Lista scuole che matchano i filtri, con checkbox per escludere singole scuole
- Le scuole in `excluded_ids` sono deselezionate di default
- Anteprima conteggio scuole selezionate
- Pulsante "Genera" → crea tappe con `data_tappa: nil` per le scuole selezionate
- Le scuole deselezionate vengono aggiunte a `excluded_ids`
- Le tappe appaiono nel planner

### Copia da giro

Dialog modale dal dropdown azioni:

- Select/combobox per scegliere il giro sorgente (es. "Collane 2025")
- Anteprima scuole che verranno copiate
- Crea tappe con `data_tappa: nil` per le scuole del giro sorgente non già presenti nel giro corrente

### Esclusione scuole

L'esclusione (`excluded_ids`) si gestisce SOLO nella dialog "Genera tappe" (checkbox deselezionate). La trash nel planner elimina la tappa senza escludere la scuola. Se si rigenera, la scuola torna (a meno che non sia stata deselezionata nella dialog).

---

## Controller

### GiriController (semplificato)

```ruby
class GiriController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro, only: %i[show edit update destroy planner]

  def index
    @giri = current_user.giri.includes(:tappe).order(created_at: :desc)
  end

  def show
    @settimane = genera_settimane(@giro.iniziato_il, @giro.finito_il)
    @tappe_per_giorno = @giro.tappe
      .con_data_tappa
      .where(data_tappa: @giro.iniziato_il..@giro.finito_il)
      .includes(:tappable, :giri)
      .group_by(&:data_tappa)
  end

  def planner
    @tappe_per_area = planner_tappe_per_area
    render partial: "giri/planner", locals: { giro: @giro, tappe_per_area: @tappe_per_area }
  end

  # new, edit, create, update, destroy — invariati ma semplificati
  # RIMUOVERE: exclude_school, include_school (gestiti in genera tappe)

  private

  def set_giro
    @giro = current_user.giri.find(params[:id])
  end

  def genera_settimane(dal, al)
    return [] unless dal && al
    primo_lunedi = dal.beginning_of_week
    ultimo_dom = al.end_of_week
    (primo_lunedi..ultimo_dom).each_slice(7).map { |days| days.first }
  end

  def planner_tappe_per_area
    @giro.tappe
      .da_programmare
      .includes(tappable: :direzione)
      .group_by { |t| t.tappable.respond_to?(:area) ? t.tappable.area : nil }
      .transform_values { |tappe| tappe.group_by { |t| t.tappable.respond_to?(:direzione) ? t.tappable.direzione : nil } }
  end
end
```

**Review notes:**
- `exclude_school`/`include_school` non sono CRUD — eliminati, la logica va nella dialog genera tappe
- Il controller diventa snello: show carica settimane + tappe, planner serve il turbo frame
- `GroupByDateService` eliminato — la logica è diretta e semplice

### Giri::TappeController (riscritta)

```ruby
class Giri::TappeController < ApplicationController
  before_action :set_giro

  # GET giri/:giro_id/genera_tappe — form con checkbox scuole
  def new
    @scuole = scuole_filtrate
  end

  # POST giri/:giro_id/genera_tappe — crea tappe per scuole selezionate
  def create
    selected_ids = params[:school_ids] || []
    all_ids = params[:all_school_ids] || []

    # Aggiorna excluded_ids con le scuole deselezionate
    deselected = all_ids - selected_ids
    @giro.update(excluded_ids: (@giro.excluded_ids + deselected).uniq)

    # Crea tappe solo per le selezionate non già presenti
    existing = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id).map(&:to_s)
    to_create = selected_ids - existing

    to_create.each do |school_id|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola", tappable_id: school_id,
        account: Current.account, data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
    end

    redirect_to giro_path(@giro), notice: "#{to_create.size} tappe generate."
  end

  # POST giri/:giro_id/copia_tappe — copia scuole da altro giro
  def copy
    source = current_user.giri.find(params[:source_giro_id])
    existing = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id)
    source_tappe = source.tappe.where(tappable_type: "Scuola").where.not(tappable_id: existing)

    count = 0
    source_tappe.find_each do |source_tappa|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola", tappable_id: source_tappa.tappable_id,
        account: Current.account, data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
      count += 1
    end

    redirect_to giro_path(@giro), notice: "#{count} tappe copiate."
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end

  def scuole_filtrate
    scuole = Current.account.scuole
    # Applica conditions del giro se presenti
    # TODO: implementare filtro per provincia/tipo/area basato su @giro.conditions
    scuole.where.not(id: @giro.excluded_ids).order(:posizione)
  end
end
```

**Review notes:**
- `GiroBulkActionsController` eliminato — tutto in `Giri::TappeController`
- `new` + `create` per genera tappe (CRUD standard)
- `copy` per copia da giro (azione custom ma accettabile)
- Account scoping tramite `Current.account`

---

## Viste

### Index, _giro, _form — restyle con pattern Fizzy

Le viste index, `_giro` e `_form` restano ma vanno aggiornate per allinearsi ai pattern Fizzy:

**`giri/index.html.erb`** — resta invariata, già usa pattern Fizzy (header grid, flex column list)

**`giri/_giro.html.erb`** — aggiungere pallino colore del giro:

```erb
<%# locals: (giro:) -%>
<div id="<%= dom_id giro %>" class="panel shadow flex gap align-center"
     style="--panel-padding: var(--block-space-half) var(--block-space);">

  <%# Pallino colore giro %>
  <span style="background: <%= giro.color %>; border-radius: 50%; flex-shrink: 0; height: 0.8em; width: 0.8em;"></span>

  <div class="flex flex-column flex-item-grow" style="min-inline-size: 0;">
    <%= link_to giro_path(giro), data: { turbo_frame: "_top" }, class: "txt-bold" do %>
      <%= giro.titolo %>
    <% end %>
    <% if giro.descrizione.present? %>
      <span class="txt-x-small txt-subtle overflow-ellipsis"><%= giro.descrizione %></span>
    <% end %>
  </div>

  <%# Periodo (se presente) %>
  <% if giro.iniziato_il.present? %>
    <span class="txt-xx-small txt-subtle hide-on-touch" style="white-space: nowrap;">
      <%= l giro.iniziato_il, format: :short %> — <%= l giro.finito_il, format: :short %>
    </span>
  <% end %>

  <span class="txt-x-small txt-subtle hide-on-touch" style="white-space: nowrap;">
    <%= giro.tappe.completate.size %>/<%= giro.tappe.size %>
  </span>

  <div class="flex gap-quarter align-center">
    <%= link_to edit_giro_path(giro),
        class: "btn btn--circle btn--plain", style: "--btn-size: 2em;",
        data: { turbo_frame: :modal, action: "click->dialog#open" } do %>
      <%= icon_tag "pencil", class: "icon--small" %>
    <% end %>

    <% if giro.can_delete? %>
      <%= button_to giro_path(giro), method: :delete,
          class: "btn btn--circle btn--negative", style: "--btn-size: 2em;",
          data: { turbo_confirm: "Eliminare?" } do %>
        <%= icon_tag "trash", class: "icon--small" %>
      <% end %>
    <% end %>
  </div>
</div>
```

**`giri/_form.html.erb`** — aggiungere campi data periodo:

```erb
<%# locals: (giro:) -%>
<%= form_with(model: giro, class: "flex flex-column gap",
    data: { action: "turbo:submit-end->dialog#close" }) do |form| %>

  <% if giro.errors.any? %>
    <div class="txt-negative txt-small">
      <%= t 'misc.errori', count: giro.errors.count %>
    </div>
  <% end %>

  <div>
    <label class="txt-small txt-bold">Titolo</label>
    <%= form.text_field :titolo, placeholder: "es. Consegna Collane", autofocus: true, class: "input" %>
  </div>

  <div>
    <label class="txt-small txt-bold">Descrizione</label>
    <%= form.text_area :descrizione, rows: 2, placeholder: "note...", class: "input input--textarea" %>
  </div>

  <div class="flex gap-half">
    <div class="flex-1">
      <label class="txt-small txt-bold">Dal</label>
      <%= form.date_field :iniziato_il, class: "input" %>
    </div>
    <div class="flex-1">
      <label class="txt-small txt-bold">Al</label>
      <%= form.date_field :finito_il, class: "input" %>
    </div>
  </div>

  <div class="color-picker__colors">
    <% Color::COLORS.each do |color| %>
      <label class="btn txt-small borderless" style="--btn-background: <%= color %>" title="<%= color.name %>">
        <%= form.radio_button :color, color.value,
            checked: (giro.color == color.value || (giro.new_record? && color.value == "var(--color-card-default)")) %>
        <%= icon_tag "check", class: "checked" %>
        <span class="for-screen-reader"><%= color.name %></span>
      </label>
    <% end %>
  </div>

  <div class="flex gap-half justify-end margin-block-start">
    <button type="button" class="btn" data-action="dialog#close">Annulla</button>
    <%= form.submit "Salva", class: "btn btn--link" %>
  </div>
<% end %>
```

**`giri/new.html.erb` e `edit.html.erb`** — usare dialog controller Fizzy:

```erb
<%= turbo_frame_tag :modal do %>
  <dialog class="dialog panel" style="--panel-size: 40ch;"
          data-controller="dialog" data-dialog-auto-open-value="true"
          data-action="keydown.esc->dialog#close:stop click->dialog#clickOutside">
    <h3 class="txt-large txt-bold">Nuovo Giro</h3>
    <%= render "form", giro: @giro %>
  </dialog>
<% end %>
```

### Show page (riscrivere)

```erb
<% content_for :hide_footer, true %>
<% @page_title = @giro.titolo %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <button type="button" class="btn btn--back"
            data-controller="hotkey toggle-class"
            data-action="click->toggle-class#toggle keydown.p@document->hotkey#click"
            data-toggle-class-selector-value=".agenda-planner"
            data-toggle-class-toggle-class="agenda-planner--collapsed">
      <%= icon_tag "calendar" %>
      <strong class="overflow-ellipsis">Planner</strong>
      <kbd class="kbd txt-x-small hide-on-touch">P</kbd>
    </button>
  </div>

  <h1 class="header__title divider divider--fade full-width">
    <span style="background: <%= @giro.color %>; border-radius: 50%; display: inline-block; height: 0.6em; width: 0.6em;"></span>
    <span class="overflow-ellipsis"><%= @giro.titolo %></span>
  </h1>

  <div class="header__actions header__actions--end">
    <%= link_to edit_giro_path(@giro), class: "btn btn--circle btn--plain",
        data: { turbo_frame: :modal, action: "click->dialog#open" } do %>
      <%= icon_tag "pencil", class: "icon--small" %>
    <% end %>

    <%# Menu dropdown azioni %>
    <details class="popup" data-controller="popup">
      <summary class="btn btn--circle btn--plain">
        <%= icon_tag "more-horizontal" %>
      </summary>
      <div class="popup__menu">
        <%= link_to genera_tappe_giro_path(@giro), class: "popup__item",
            data: { turbo_frame: :modal, action: "click->dialog#open" } do %>
          <%= icon_tag "add", class: "icon--small" %>
          Genera tappe
        <% end %>
        <button type="button" class="popup__item"
                data-action="click->dialog#open"
                data-dialog-target="trigger">
          <%= icon_tag "copy", class: "icon--small" %>
          Copia da giro
        </button>
        <% if @giro.can_delete? %>
          <hr class="popup__divider">
          <%= button_to giro_path(@giro), method: :delete,
              class: "popup__item txt-negative",
              data: { turbo_confirm: "Eliminare questo giro?" } do %>
            <%= icon_tag "trash", class: "icon--small" %>
            Elimina giro
          <% end %>
        <% end %>
      </div>
    </details>
  </div>
<% end %>

<%# Planner — turbo frame caricato async %>
<%= turbo_frame_tag "giro-planner", src: giro_planner_path(@giro) do %>
  <div class="agenda-planner" data-controller="agenda-planner">
    <div class="agenda-planner__header">
      <span class="agenda-planner__title">Da programmare <span class="spinner spinner--small"></span></span>
    </div>
  </div>
<% end %>

<%# Griglia settimanale compatta — solo periodo del giro %>
<div class="agenda-calendar" data-controller="agenda-calendar">
  <div id="weeks-container">
    <% @settimane.each do |lunedi| %>
      <%= render "agenda/week", lunedi: lunedi, tappe_per_giorno: @tappe_per_giorno %>
    <% end %>
  </div>
</div>
```

### Partial planner giro

`giri/_planner.html.erb` — riusa `_planner_body` dell'agenda:

```erb
<%# locals: (giro:, tappe_per_area:) -%>
<div class="agenda-planner" data-controller="agenda-planner">
  <div class="agenda-planner__header"
       data-action="mousedown->agenda-planner#panelDragStart dblclick->agenda-planner#panelDock">
    <span class="agenda-planner__title">
      Da programmare
      <span class="badge"><%= tappe_per_area.values.flat_map(&:values).flatten.size %></span>
    </span>
    <div class="agenda-planner__trash"
         data-agenda-planner-target="trash"
         data-action="dragover->agenda-planner#trashOver dragleave->agenda-planner#trashLeave drop->agenda-planner#trashDrop">
      <%= icon_tag "trash", class: "icon--small" %>
    </div>
    <button type="button" class="agenda-planner__close" data-action="agenda-planner#close">
      <%= icon_tag "close", class: "icon--small" %>
    </button>
  </div>

  <div class="agenda-planner__body" id="planner-body"
       data-agenda-planner-target="body"
       data-action="dragover->agenda-planner#dropzoneOver dragleave->agenda-planner#dropzoneLeave drop->agenda-planner#dropzoneDrop">
    <%= render "agenda/planner_body", tappe_per_area: tappe_per_area %>
  </div>
</div>
```

### Dialog genera tappe

`giri/_genera_tappe.html.erb`:

```erb
<dialog class="dialog panel" style="--panel-size: 60ch;"
        data-controller="dialog" data-dialog-auto-open-value="true">
  <h3 class="txt-large txt-bold">Genera tappe</h3>
  <p class="txt-small txt-subtle">Seleziona le scuole da includere nel giro.</p>

  <%= form_with url: genera_tappe_giro_path(@giro), method: :post,
      class: "flex flex-column gap" do |f| %>

    <div class="flex flex-column gap-quarter" style="max-block-size: 50vh; overflow-y: auto;">
      <% @scuole.each do |scuola| %>
        <% checked = !@giro.excluded_ids.include?(scuola.id.to_s) %>
        <label class="flex gap-half align-center pad-block-quarter">
          <input type="checkbox" name="school_ids[]" value="<%= scuola.id %>"
                 <%= "checked" if checked %> class="input--checkbox">
          <input type="hidden" name="all_school_ids[]" value="<%= scuola.id %>">
          <span class="txt-small"><%= scuola.denominazione %></span>
          <span class="txt-xx-small txt-subtle"><%= scuola.comune %></span>
        </label>
      <% end %>
    </div>

    <div class="flex gap-half justify-end">
      <button type="button" class="btn" data-action="dialog#close">Annulla</button>
      <%= f.submit "Genera", class: "btn btn--link" %>
    </div>
  <% end %>
</dialog>
```

### Dialog copia da giro

`giri/_copia_da_giro.html.erb`:

```erb
<dialog class="dialog panel" style="--panel-size: 40ch;"
        data-controller="dialog" data-dialog-auto-open-value="true">
  <h3 class="txt-large txt-bold">Copia da giro</h3>

  <%= form_with url: copia_tappe_giro_path(@giro), method: :post,
      class: "flex flex-column gap" do |f| %>

    <div>
      <label class="txt-small txt-bold">Giro sorgente</label>
      <%= f.select :source_giro_id,
          options_from_collection_for_select(current_user.giri.where.not(id: @giro.id), :id, :titolo),
          { prompt: "Seleziona un giro..." },
          class: "input input--select" %>
    </div>

    <div class="flex gap-half justify-end">
      <button type="button" class="btn" data-action="dialog#close">Annulla</button>
      <%= f.submit "Copia", class: "btn btn--link" %>
    </div>
  <% end %>
</dialog>
```

---

## Da eliminare

### Viste
- `giri/_giro_filter.html.erb` — tab filtri non servono più
- `giri/_tappe_del_giorno.html.erb` — sostituito dalla griglia con `_tappa_compact`

### Service/Controller
- `app/services/tappe/group_by_date_service.rb` — logica diretta nel controller
- `app/controllers/tappe/giro_bulk_actions_controller.rb` — assorbito da `Giri::TappeController`

### Azioni controller
- `GiriController#exclude_school` — gestito in genera tappe dialog
- `GiriController#include_school` — gestito in genera tappe dialog

---

## Stimulus

`agenda_planner_controller.js` funziona già per il drag & drop planner ↔ calendar. L'endpoint sort è lo stesso (`tappe/:id/sort`). Il controller usa `accountPrefix` per costruire gli URL.

**Adattamento necessario:** il turbo stream per `source: "to_planner"` deve sapere quale giro per caricare le tappe giuste. Opzioni:
- Passare `giro_id` nel body del PATCH sort
- Il server usa il giro_id per filtrare le tappe nel planner body update

**`tappa_dropzone_controller.js`** — da eliminare, non serve più (il drag & drop è gestito dal planner + SortableJS).

---

## Routes

```ruby
resources :giri do
  member do
    get 'planner'
  end

  # Genera tappe (form + create)
  get  'genera_tappe', to: 'giri/tappe#new'
  post 'genera_tappe', to: 'giri/tappe#create'

  # Copia da giro
  post 'copia_tappe', to: 'giri/tappe#copy'
end

# RIMUOVERE:
# - bulk_create_tappe route
# - remove_tappa route
# - exclude_school route
# - include_school route
```

---

## Componenti CSS riusati

Tutti da `agenda-calendar.css`, nessuna duplicazione:
- `.agenda-week`, `.agenda-week__day`, `.agenda-week__weekend` — griglia
- `.tappa-compact`, `.tappa-compact__content`, `.tappa-compact__name` — card tappa
- `.agenda-planner`, `.agenda-planner__header`, `.agenda-planner__body` — planner
- `.agenda-planner__tappa`, `.agenda-planner__direzione` — elementi planner
- `.agenda-planner__trash` — trash zone

Pattern Fizzy usati:
- `.panel`, `.shadow` — card container
- `.dialog`, `--panel-size` — dialog modali
- `.input`, `.input--select`, `.input--textarea` — form inputs
- `.color-picker__colors` — color picker con radio buttons
- `.btn`, `.btn--link`, `.btn--circle`, `.btn--plain` — bottoni
- `.popup`, `.popup__menu`, `.popup__item` — dropdown menu
- Header grid: `.header__title`, `.header__actions--start/--end`
- Utilities: `.flex`, `.gap`, `.txt-*`, `.overflow-ellipsis`
