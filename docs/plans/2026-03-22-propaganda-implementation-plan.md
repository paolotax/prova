# Propaganda Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a spreadsheet-style page showing all schools as rows and open giri as columns, with tappa status, bolle, and book counts in each cell.

**Architecture:** Dedicated `PropagandaController#index` with a hash-based lookup `{[scuola_id, giro_id] => tappa}` for O(1) cell rendering. Uses `Current.scuole` for account-scoped schools, `tappa_color` helper for cell backgrounds.

**Tech Stack:** Rails controller, ERB views, existing Fizzy CSS classes, TappeHelper.

---

### Task 1: Route and Controller

**Files:**
- Modify: `config/routes.rb` (inside the account-scoped block, near `resources :giri`)
- Create: `app/controllers/propaganda_controller.rb`

**Step 1: Add route**

In `config/routes.rb`, inside the scoped block (same level as `resources :giri` at line ~336), add:

```ruby
resources :propaganda, only: [:index]
```

**Step 2: Create controller**

Create `app/controllers/propaganda_controller.rb`:

```ruby
class PropagandaController < ApplicationController
  before_action :authenticate_user!

  def index
    @giri = load_giri
    @scuole = Current.scuole
      .where(direzione_id: nil)
      .or(Current.scuole.where.not(direzione_id: nil))
      .order(:provincia, :area, :denominazione)

    @tappe_map = build_tappe_map
  end

  private

  def load_giri
    if params[:giro_ids].present?
      current_user.giri.where(id: params[:giro_ids])
    else
      current_user.giri.where(finito_il: nil)
    end
  end

  def build_tappe_map
    return {} if @giri.empty?

    tappe = Tappa.where(tappable_type: "Scuola", tappable_id: @scuole.select(:id))
      .joins(:tappa_giri).where(tappa_giri: { giro_id: @giri.select(:id) })
      .includes(:entry, :tappa_giri, bolle_visione: :bolla_visione_righe)

    map = {}
    tappe.each do |tappa|
      tappa.tappa_giri.each do |tg|
        next unless @giri.pluck(:id).include?(tg.giro_id)
        map[[tappa.tappable_id, tg.giro_id]] = tappa
      end
    end
    map
  end
end
```

**Step 3: Verify route exists**

Run: `docker exec prova-app-1 bin/rails routes -g propaganda`
Expected: `propaganda GET /propaganda(.:format) propaganda#index`

**Step 4: Commit**

```
feat: add PropagandaController with route and query logic
```

---

### Task 2: Index View — Table Layout

**Files:**
- Create: `app/views/propaganda/index.html.erb`

**Step 1: Create the view**

```erb
<% @page_title = "Propaganda" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start"></div>

  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis">Propaganda</span>
  </h1>

  <div class="header__actions header__actions--end"></div>
<% end %>

<div class="pad">
  <%# Filtro giri %>
  <turbo-frame id="propaganda-table">
    <%= form_with url: propaganda_index_path, method: :get, data: { turbo_frame: "propaganda-table" } do |f| %>
      <div class="flex gap-half align-center margin-block-end">
        <% current_user.giri.order(created_at: :desc).each do |giro| %>
          <label class="flex gap-quarter align-center txt-small">
            <%= check_box_tag "giro_ids[]", giro.id,
                @giri.map(&:id).include?(giro.id),
                onchange: "this.form.requestSubmit()" %>
            <span style="color: <%= giro.color %>;">&#9679;</span>
            <%= giro.titolo %>
          </label>
        <% end %>
      </div>
    <% end %>

    <% if @giri.any? %>
      <div style="overflow-x: auto;">
        <table class="table" style="white-space: nowrap; font-size: var(--font-size-small);">
          <thead>
            <tr>
              <th class="txt-left" style="position: sticky; left: 0; background: var(--color-bg); z-index: 1;">Provincia</th>
              <th class="txt-left">Area</th>
              <th class="txt-left" style="position: sticky; left: 0; background: var(--color-bg);">Scuola</th>
              <% @giri.each do |giro| %>
                <th class="txt-center">
                  <span style="color: <%= giro.color %>;">&#9679;</span>
                  <%= giro.titolo %>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody>
            <% @scuole.each do |scuola| %>
              <tr>
                <td class="txt-subtle" style="position: sticky; left: 0; background: var(--color-bg);"><%= scuola.sigla_provincia %></td>
                <td class="txt-subtle"><%= scuola.area %></td>
                <td style="position: sticky; left: 0; background: var(--color-bg);"><%= scuola.denominazione %></td>
                <% @giri.each do |giro| %>
                  <% tappa = @tappe_map[[scuola.id, giro.id]] %>
                  <td style="<%= "background: #{tappa_color(tappa)}; color: white;" if tappa %> padding: 0.25rem 0.5rem;">
                    <% if tappa %>
                      <%= render "propaganda/cella", tappa: tappa %>
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% else %>
      <p class="txt-subtle txt-center pad-block-double">Nessun giro aperto</p>
    <% end %>
  </turbo-frame>
</div>
```

**Step 2: Commit**

```
feat: add propaganda index view with spreadsheet table
```

---

### Task 3: Cell Partial

**Files:**
- Create: `app/views/propaganda/_cella.html.erb`

**Step 1: Create the partial**

```erb
<%# locals: (tappa:) %>
<div class="flex flex-column" style="font-size: var(--font-size-xs); line-height: 1.3;">
  <% if tappa.data_tappa.present? %>
    <span class="font-weight-bold"><%= l(tappa.data_tappa, format: "%-d %b") %></span>
  <% else %>
    <span class="txt-subtle">da progr.</span>
  <% end %>

  <% bolle_count = tappa.bolle_visione.size %>
  <% libri_count = tappa.bolle_visione.sum { |b| b.bolla_visione_righe.size } %>
  <% if bolle_count > 0 %>
    <span><%= bolle_count %> bolle · <%= libri_count %> libri</span>
  <% end %>

  <% if tappa.descrizione.present? %>
    <span class="txt-subtle" style="max-inline-size: 20ch; overflow: hidden; text-overflow: ellipsis;"><%= truncate(tappa.descrizione, length: 30) %></span>
  <% end %>
</div>
```

**Step 2: Verify page loads**

Visit: `http://localhost:3000/propaganda`
Expected: table with schools as rows, open giri as columns, colored cells for tappe

**Step 3: Commit**

```
feat: add propaganda cell partial with tappa details
```

---

### Task 4: Visual Polish

**Files:**
- Modify: `app/views/propaganda/index.html.erb` (adjustments after visual review)

**Step 1: Review in browser and adjust**

Check:
- Table scrolls horizontally with many giri
- Sticky columns (Provincia, Scuola) stay visible during scroll
- Cell colors match timeline colors
- Empty cells are clean white
- Checkbox filter works (submits form, updates table via Turbo Frame)
- Text is readable on colored backgrounds

**Step 2: Fix any visual issues found**

Typical adjustments:
- Sticky column widths
- Color contrast (white text on colored background)
- Cell padding/spacing
- Table border styling

**Step 3: Commit**

```
fix: polish propaganda table layout and styling
```
