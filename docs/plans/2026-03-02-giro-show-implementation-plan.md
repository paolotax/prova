# Giro Show Page Redesign - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the giro show page kanban with a weekly calendar grid + planner panel, reusing agenda components.

**Architecture:** Giro show becomes a compact weekly calendar (only the giro's date range) with an agenda-planner panel for unscheduled tappe. Drag & drop between planner and calendar reuses existing controllers. "Genera tappe" and "Copia da giro" use dialog modals.

**Tech Stack:** Rails views, Turbo Frames, existing Stimulus controllers (agenda-planner, tappa-date, tax-sortable, toggle-class, hotkey), existing CSS from agenda-calendar.css.

**Design doc:** `docs/plans/2026-03-02-giro-show-redesign.md`

---

### Task 1: Update routes

**Files:**
- Modify: `config/routes.rb`

**Step 1: Update giri routes**

Replace the current giri routes block with:

```ruby
resources :giri do
  member do
    get 'planner'
  end

  # Genera tappe
  get  'genera_tappe', to: 'giri/tappe#new', as: 'genera_tappe'
  post 'genera_tappe', to: 'giri/tappe#create'

  # Copia da giro
  post 'copia_tappe', to: 'giri/tappe#copy', as: 'copia_tappe'
end
```

Remove the old nested routes: `resources :tappe`, `post 'tappe'`, `bulk_create_tappe`, `remove_tappa`, `exclude_school`, `include_school`.

Keep `resources :tappe` with `sort` at the top level (already exists).

**Step 2: Verify routes compile**

Run: `docker exec prova-app-1 bin/rails routes | grep giri`

**Step 3: Commit**

```
feat: update giri routes for show page redesign
```

---

### Task 2: Rewrite GiriController#show and add #planner

**Files:**
- Modify: `app/controllers/giri_controller.rb`

**Step 1: Rewrite the controller**

Replace `show` action:

```ruby
def show
  @settimane = genera_settimane(@giro.iniziato_il, @giro.finito_il)
  @tappe_per_giorno = @giro.tappe
    .con_data_tappa
    .includes(:tappable, :giri)
    .group_by(&:data_tappa)
end
```

Add `planner` action:

```ruby
def planner
  tappe_per_area = planner_tappe_per_area
  total_count = tappe_per_area.values.flat_map { |dirs| dirs.flat_map(&:last) }.size

  render partial: "giri/planner", locals: {
    giro: @giro,
    tappe_per_area: tappe_per_area,
    total_count: total_count
  }
end
```

Add private helpers:

```ruby
def genera_settimane(dal, al)
  return [] unless dal && al
  primo_lunedi = dal.beginning_of_week
  ultimo_dom = al.end_of_week
  (primo_lunedi..ultimo_dom).group_by { |d| d.beginning_of_week }.values
end

def planner_tappe_per_area
  @giro.tappe
    .da_programmare
    .where(tappable_type: "Scuola")
    .includes(:giri)
    .preload(:tappable)
    .group_by { |t| t.tappable.respond_to?(:area) ? (t.tappable.area.presence || "Senza area") : "Senza area" }
    .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
    .map { |area, area_tappe|
      direzioni = area_tappe
        .group_by { |t| t.tappable.respond_to?(:direzione) ? (t.tappable.direzione || t.tappable) : t.tappable }
        .sort_by { |dir, _| dir.respond_to?(:denominazione) ? dir.denominazione : "" }
      [area, direzioni]
    }
end
```

Remove: `exclude_school`, `include_school` actions. Update `before_action` to include `planner`.

Simplify `create`/`update`/`destroy` — remove `hotwire_native_app?` branching if not needed, keep broadcasts.

**Step 2: Verify controller loads**

Run: `docker exec prova-app-1 bin/rails runner "GiriController"`

**Step 3: Commit**

```
refactor: simplify GiriController with calendar show and planner endpoint
```

---

### Task 3: Rewrite Giri::TappeController

**Files:**
- Modify: `app/controllers/giri/tappe_controller.rb`

**Step 1: Rewrite with new/create/copy actions**

```ruby
class Giri::TappeController < ApplicationController
  before_action :authenticate_user!
  before_action :set_giro

  # GET /giri/:giro_id/genera_tappe
  def new
    @scuole = scuole_filtrate
    existing_ids = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id).map(&:to_s)
    @scuole = @scuole.reject { |s| existing_ids.include?(s.id.to_s) }
  end

  # POST /giri/:giro_id/genera_tappe
  def create
    selected_ids = Array(params[:school_ids]).map(&:to_s)
    all_ids = Array(params[:all_school_ids]).map(&:to_s)

    # Aggiorna excluded_ids con le scuole deselezionate
    deselected = all_ids - selected_ids
    new_excluded = ((@giro.excluded_ids || []) + deselected).uniq
    @giro.update!(excluded_ids: new_excluded)

    # Crea tappe solo per le selezionate
    count = 0
    selected_ids.each do |school_id|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: school_id,
        account: Current.account,
        data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
      count += 1
    end

    redirect_to giro_path(@giro), notice: "#{count} tappe generate."
  end

  # POST /giri/:giro_id/copia_tappe
  def copy
    source = current_user.giri.find(params[:source_giro_id])
    existing_ids = @giro.tappe.where(tappable_type: "Scuola").pluck(:tappable_id)

    source_tappe = source.tappe
      .where(tappable_type: "Scuola")
      .where.not(tappable_id: existing_ids)

    count = 0
    source_tappe.find_each do |source_tappa|
      tappa = current_user.tappe.create!(
        tappable_type: "Scuola",
        tappable_id: source_tappa.tappable_id,
        account: Current.account,
        data_tappa: nil
      )
      tappa.tappa_giri.create!(giro: @giro)
      count += 1
    end

    redirect_to giro_path(@giro), notice: "#{count} tappe copiate da #{source.titolo}."
  end

  private

  def set_giro
    @giro = current_user.giri.find(params[:giro_id])
  end

  def scuole_filtrate
    scuole = Current.account.scuole
    excluded = @giro.excluded_ids || []
    scuole = scuole.where.not(id: excluded) if excluded.any?
    scuole.order(:posizione)
  end
end
```

**Step 2: Commit**

```
refactor: rewrite Giri::TappeController with genera/copia actions
```

---

### Task 4: Rewrite giri/show.html.erb

**Files:**
- Modify: `app/views/giri/show.html.erb`

**Step 1: Rewrite the show page**

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
    <span style="background: <%= @giro.color %>; border-radius: 50%; display: inline-block; block-size: 0.6em; inline-size: 0.6em;"></span>
    <span class="overflow-ellipsis"><%= @giro.titolo %></span>
  </h1>

  <div class="header__actions header__actions--end">
    <%= link_to edit_giro_path(@giro), class: "btn btn--circle btn--plain",
        data: { turbo_frame: :modal, action: "click->dialog#open" } do %>
      <%= icon_tag "pencil", class: "icon--small" %>
    <% end %>

    <details class="popup" data-controller="popup">
      <summary class="btn btn--circle btn--plain">
        <%= icon_tag "more-horizontal" %>
      </summary>
      <div class="popup__menu">
        <%= link_to genera_tappe_giro_path(@giro), class: "popup__item",
            data: { turbo_frame: :modal } do %>
          <%= icon_tag "add", class: "icon--small" %>
          Genera tappe
        <% end %>

        <%= link_to "#", class: "popup__item",
            data: { turbo_frame: :modal, action: "click->dialog#open" } do %>
          <%= icon_tag "copy", class: "icon--small" %>
          Copia da giro
        <% end %>

        <% if @giro.can_delete? %>
          <hr class="popup__divider">
          <%= button_to giro_path(@giro), method: :delete,
              class: "popup__item txt-negative",
              data: { turbo_confirm: "Eliminare questo giro e tutte le sue tappe?" } do %>
            <%= icon_tag "trash", class: "icon--small" %>
            Elimina giro
          <% end %>
        <% end %>
      </div>
    </details>
  </div>
<% end %>

<%# Planner — turbo frame caricato async %>
<%= turbo_frame_tag "giro-planner", src: planner_giro_path(@giro) do %>
  <div class="agenda-planner" data-controller="agenda-planner">
    <div class="agenda-planner__header">
      <span class="agenda-planner__title">Da programmare <span class="spinner spinner--small"></span></span>
    </div>
  </div>
<% end %>

<%# Griglia settimanale compatta — solo periodo del giro %>
<% if @settimane.any? %>
  <div class="agenda-calendar">
    <div id="weeks-container">
      <% @settimane.each do |settimana| %>
        <%= render "agenda/week", settimana: settimana, tappe_per_giorno: @tappe_per_giorno %>
      <% end %>
    </div>
  </div>
<% else %>
  <div class="blank-slate margin-block">
    Imposta le date del giro (dal/al) per visualizzare il calendario.
  </div>
<% end %>
```

**Step 2: Commit**

```
feat: rewrite giri/show with calendar grid and planner
```

---

### Task 5: Create giri/_planner.html.erb

**Files:**
- Create: `app/views/giri/_planner.html.erb`

**Step 1: Create the planner partial**

This is similar to `agenda/_planner.html.erb` but without the giro filter select (we're already in a giro context):

```erb
<%# locals: (giro:, tappe_per_area:, total_count:) -%>

<%= turbo_frame_tag "giro-planner" do %>
  <div class="agenda-planner" data-controller="agenda-planner">
    <div class="agenda-planner__header"
         data-agenda-planner-target="header"
         data-action="mousedown->agenda-planner#panelDragStart dblclick->agenda-planner#panelDock">
      <span class="agenda-planner__title">
        Da programmare
        <span class="badge"><%= total_count %></span>
      </span>

      <div class="agenda-planner__trash" data-agenda-planner-target="trash"
           data-action="dragover->agenda-planner#trashOver drop->agenda-planner#trashDrop dragleave->agenda-planner#trashLeave">
        <%= icon_tag "trash", class: "icon--small" %>
      </div>

      <button type="button" class="agenda-planner__close" data-action="click->agenda-planner#close">
        <%= icon_tag "close", class: "icon--small" %>
      </button>
    </div>

    <div id="planner-body" class="agenda-planner__body" data-agenda-planner-target="body"
         data-action="dragover->agenda-planner#dropzoneOver drop->agenda-planner#dropzoneDrop dragleave->agenda-planner#dropzoneLeave">
      <%= render "agenda/planner_body", tappe_per_area: tappe_per_area %>
    </div>
  </div>
<% end %>
```

Note: This reuses `agenda/planner_body` directly — same partial, same structure.

**Step 2: Commit**

```
feat: add giri planner partial reusing agenda planner components
```

---

### Task 6: Create genera_tappe dialog

**Files:**
- Create: `app/views/giri/tappe/new.html.erb`

**Step 1: Create the dialog view**

```erb
<%= turbo_frame_tag :modal do %>
  <dialog class="dialog panel" style="--panel-size: 60ch;"
          data-controller="dialog" data-dialog-auto-open-value="true"
          data-action="keydown.esc->dialog#close:stop">
    <h3 class="txt-large txt-bold">Genera tappe</h3>
    <p class="txt-small txt-subtle margin-block-end">
      Seleziona le scuole da includere nel giro. Le scuole deselezionate verranno escluse.
    </p>

    <%= form_with url: genera_tappe_giro_path(@giro), method: :post,
        class: "flex flex-column gap" do |f| %>

      <div class="flex flex-column gap-quarter" style="max-block-size: 50vh; overflow-y: auto; padding: 0.5em;">
        <% @scuole.group_by(&:comune).sort_by { |k, _| k.to_s }.each do |comune, scuole| %>
          <div class="txt-xx-small txt-bold txt-subtle margin-block-start-half"><%= comune || "Senza comune" %></div>
          <% scuole.each do |scuola| %>
            <label class="flex gap-half align-center">
              <input type="checkbox" name="school_ids[]" value="<%= scuola.id %>" checked>
              <input type="hidden" name="all_school_ids[]" value="<%= scuola.id %>">
              <span class="txt-small"><%= scuola.denominazione %></span>
            </label>
          <% end %>
        <% end %>
      </div>

      <div class="flex gap-half justify-end margin-block-start">
        <button type="button" class="btn" data-action="dialog#close">Annulla</button>
        <%= f.submit "Genera #{@scuole.size} tappe", class: "btn btn--link" %>
      </div>
    <% end %>
  </dialog>
<% end %>
```

**Step 2: Commit**

```
feat: add genera tappe dialog with school checkboxes
```

---

### Task 7: Create copia da giro dialog

**Files:**
- Modify: `app/views/giri/show.html.erb` (or create separate partial)

For the copia dialog, we need a turbo frame endpoint. Simplest approach: add a `copia` action to the controller that renders the dialog, or embed it directly in the show page.

**Step 1: Add copia endpoint to GiriController**

Add to `giri_controller.rb`:

```ruby
def copia
  @altri_giri = current_user.giri.where.not(id: @giro.id).order(created_at: :desc)
end
```

Update `before_action` and routes to include `copia`.

Add route:

```ruby
member do
  get 'planner'
  get 'copia', to: 'giri#copia'
end
```

**Step 2: Create view**

Create `app/views/giri/copia.html.erb`:

```erb
<%= turbo_frame_tag :modal do %>
  <dialog class="dialog panel" style="--panel-size: 40ch;"
          data-controller="dialog" data-dialog-auto-open-value="true"
          data-action="keydown.esc->dialog#close:stop">
    <h3 class="txt-large txt-bold">Copia da giro</h3>

    <%= form_with url: copia_tappe_giro_path(@giro), method: :post,
        class: "flex flex-column gap" do |f| %>

      <div>
        <label class="txt-small txt-bold">Giro sorgente</label>
        <select name="source_giro_id" class="input input--select" required>
          <option value="">Seleziona un giro...</option>
          <% @altri_giri.each do |g| %>
            <option value="<%= g.id %>"><%= g.titolo %> (<%= g.tappe.size %> tappe)</option>
          <% end %>
        </select>
      </div>

      <div class="flex gap-half justify-end margin-block-start">
        <button type="button" class="btn" data-action="dialog#close">Annulla</button>
        <%= f.submit "Copia", class: "btn btn--link" %>
      </div>
    <% end %>
  </dialog>
<% end %>
```

**Step 3: Update show page dropdown**

Change "Copia da giro" link in show.html.erb to:

```erb
<%= link_to copia_giro_path(@giro), class: "popup__item",
    data: { turbo_frame: :modal } do %>
  <%= icon_tag "copy", class: "icon--small" %>
  Copia da giro
<% end %>
```

**Step 4: Commit**

```
feat: add copia da giro dialog
```

---

### Task 8: Update TappeController#sort for giro planner context

**Files:**
- Modify: `app/controllers/tappe_controller.rb`
- Modify: `app/views/tappe/sort.turbo_stream.erb`

**Step 1: Handle giro_id in sort for planner refresh**

In `tappe_controller.rb`, update the `planner_tappe_per_area` method to handle giro context:

```ruby
def sort
  @tappa = current_user.tappe.find(params[:id])

  posizione = params[:position].to_i
  data_tappa = params[:data_tappa]

  @tappa.update(position: posizione, data_tappa: data_tappa)

  if params[:source] == "to_planner"
    if params[:giro_id].present?
      @planner_tappe_per_area = giro_planner_tappe_per_area(params[:giro_id])
    else
      @planner_tappe_per_area = planner_tappe_per_area
    end
  end

  respond_to do |format|
    format.turbo_stream
    format.html { head :no_content }
  end
end
```

Add private helper:

```ruby
def giro_planner_tappe_per_area(giro_id)
  giro = current_user.giri.find(giro_id)
  giro.tappe
    .da_programmare
    .where(tappable_type: "Scuola")
    .includes(:giri)
    .preload(:tappable)
    .group_by { |t| t.tappable.respond_to?(:area) ? (t.tappable.area.presence || "Senza area") : "Senza area" }
    .sort_by { |area, _| area == "Senza area" ? "zzz" : area }
    .map { |area, area_tappe|
      direzioni = area_tappe
        .group_by { |t| t.tappable.respond_to?(:direzione) ? (t.tappable.direzione || t.tappable) : t.tappable }
        .sort_by { |dir, _| dir.respond_to?(:denominazione) ? dir.denominazione : "" }
      [area, direzioni]
    }
end
```

**Step 2: The sort.turbo_stream.erb already works** — it uses `planner-body` as the target ID which is the same in both agenda and giro planner. No changes needed there.

**Step 3: Commit**

```
feat: support giro context in tappe sort for planner refresh
```

---

### Task 9: Update agenda_planner_controller.js to pass giro_id

**Files:**
- Modify: `app/javascript/controllers/agenda_planner_controller.js`

**Step 1: Add giro_id support**

The planner controller needs to pass `giro_id` when dropping to planner so the server refreshes with the right tappe. Add a value:

```javascript
static values = { giroId: String }
```

In `dropzoneDrop`, when calling the last PATCH with `source: "to_planner"`, include giro_id:

```javascript
const body = { data_tappa: null, position: 0, source: "to_planner" }
if (this.hasGiroIdValue) body.giro_id = this.giroIdValue

await patch(`${prefix}/tappe/${lastId}/sort`, {
  body: JSON.stringify(body),
  responseKind: "turbo-stream"
})
```

Same for `trashDrop` — no change needed, trash just deletes.

**Step 2: Add data attribute to giro planner**

In `giri/_planner.html.erb`, add the giro ID value:

```erb
<div class="agenda-planner"
     data-controller="agenda-planner"
     data-agenda-planner-giro-id-value="<%= giro.id %>">
```

**Step 3: Commit**

```
feat: pass giro_id from planner to sort endpoint for context-aware refresh
```

---

### Task 10: Restyle _giro.html.erb and _form.html.erb

**Files:**
- Modify: `app/views/giri/_giro.html.erb`
- Modify: `app/views/giri/_form.html.erb`
- Modify: `app/views/giri/new.html.erb`
- Modify: `app/views/giri/edit.html.erb`

**Step 1: Update _giro.html.erb** — add color dot and period dates:

```erb
<%# locals: (giro:) -%>

<div id="<%= dom_id giro %>" class="panel shadow flex gap align-center"
     style="--panel-padding: var(--block-space-half) var(--block-space);">

  <span style="background: <%= giro.color %>; border-radius: 50%; flex-shrink: 0; block-size: 0.8em; inline-size: 0.8em;"></span>

  <div class="flex flex-column flex-item-grow" style="min-inline-size: 0;">
    <%= link_to giro_path(giro), data: { turbo_frame: "_top" }, class: "txt-bold" do %>
      <%= giro.titolo %>
    <% end %>
    <% if giro.descrizione.present? %>
      <span class="txt-x-small txt-subtle overflow-ellipsis"><%= giro.descrizione %></span>
    <% end %>
  </div>

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

**Step 2: Update _form.html.erb** — add date fields and dialog close on submit:

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

**Step 3: Update new.html.erb and edit.html.erb** — use Fizzy dialog controller:

```erb
<%= turbo_frame_tag :modal do %>
  <dialog class="dialog panel" style="--panel-size: 40ch;"
          data-controller="dialog" data-dialog-auto-open-value="true"
          data-action="keydown.esc->dialog#close:stop">
    <h3 class="txt-large txt-bold">Nuovo Giro</h3>
    <%= render "form", giro: @giro %>
  </dialog>
<% end %>
```

(Same for edit with "Modifica Giro" title)

**Step 4: Commit**

```
feat: restyle giro card, form with date fields, and Fizzy dialog pattern
```

---

### Task 11: Cleanup — delete obsolete files

**Files:**
- Delete: `app/views/giri/_giro_filter.html.erb`
- Delete: `app/views/giri/_tappe_del_giorno.html.erb`
- Delete: `app/controllers/tappe/giro_bulk_actions_controller.rb`
- Delete: `app/services/tappe/group_by_date_service.rb`
- Delete: `app/views/giri/show.json.jbuilder` (if exists)
- Delete: `app/views/giri/index.json.jbuilder` (if exists)
- Delete: `app/views/giri/_giro.json.jbuilder` (if exists)

**Step 1: Delete files**

```bash
git rm app/views/giri/_giro_filter.html.erb
git rm app/views/giri/_tappe_del_giorno.html.erb
git rm app/controllers/tappe/giro_bulk_actions_controller.rb
git rm app/services/tappe/group_by_date_service.rb
```

Also delete JSON jbuilder files if they exist.

**Step 2: Verify no references remain**

Search for `GroupByDateService`, `giro_bulk_actions`, `_giro_filter`, `_tappe_del_giorno` across codebase.

**Step 3: Commit**

```
chore: remove obsolete giro views, service, and controller
```

---

### Task 12: Smoke test the full flow

**Step 1: Run tests**

```bash
docker exec prova-app-1 bin/rails test
```

Fix any failures from removed routes/controllers.

**Step 2: Manual test checklist**

- [ ] Giri index loads with color dots and date ranges
- [ ] New giro dialog opens with date fields
- [ ] Edit giro dialog works
- [ ] Giro show page shows calendar grid for the period
- [ ] Planner loads with unscheduled tappe
- [ ] Drag tappa from planner to calendar day works
- [ ] Drag tappa from calendar back to planner works
- [ ] Trash zone in planner works
- [ ] Drag between calendar days works (SortableJS)
- [ ] P key toggles planner
- [ ] "Genera tappe" dialog shows schools with checkboxes
- [ ] "Copia da giro" dialog works
- [ ] Blank state shown when no dates set

**Step 3: Final commit**

```
test: verify giro show page redesign
```
