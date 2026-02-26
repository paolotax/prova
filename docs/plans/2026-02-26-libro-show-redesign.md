# Libro Show Page Redesign - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the libro show page with adozioni/concorrenza button in notch, movimenti di magazzino list (da consegnare first), crosstab riepilogo per anno, and lazy-loaded completati.

**Architecture:** PORO `Libro::Movimenti` encapsulates all movement queries. New `Libri::MovimentiController#show` serves lazy-loaded turbo frame for riepilogo + completati. Footer template rewritten to show da_consegnare inline and lazy-load the rest.

**Tech Stack:** Rails 8, Turbo Frames (lazy loading), PORO pattern, existing Fizzy CSS classes

---

### Task 1: Create PORO `Libro::Movimenti`

**Files:**
- Create: `app/models/libro/movimenti.rb`

**Step 1: Create the directory and PORO file**

```ruby
# app/models/libro/movimenti.rb
class Libro::Movimenti
  attr_reader :libro

  def initialize(libro)
    @libro = libro
  end

  # Righe da documenti attivi, senza consegna, solo padri o senza padre
  def da_consegnare
    righe_base.merge(Documento.attivi)
              .merge(Documento.where.missing(:consegna))
  end

  # Righe da documenti con consegna, solo padri o senza padre
  def completati
    righe_base.merge(Documento.where.associated(:consegna))
  end

  # Crosstab: { 2024 => { "ordine" => N, "vendita" => N, "carico" => N, importo: N }, ... }
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
      .includes(:riga, documento: [:causale, :clientable, :consegna, :entry])
      .where(riga: { libro_id: libro.id })
      .where(documenti: { documento_padre_id: nil })
      .order("documenti.data_documento DESC")
  end

  def aggregate(documento_righe)
    result = Hash.new(0)
    documento_righe.each do |dr|
      tipo = dr.documento.causale&.tipo_movimento || "altro"
      result[tipo] += dr.riga.quantita
      result[:importo] += dr.riga.importo_cents
    end
    result
  end
end
```

Note: `righe_base` queries `DocumentoRiga` directly (not through `libro.documento_righe` which is a `through:` association) to allow clean `.merge()` with Documento scopes. Filters `riga.libro_id` and `documenti.documento_padre_id IS NULL`.

**Step 2: Verify it loads in console**

Run: `docker exec prova-app-1 bin/rails runner "libro = Libro.first; m = Libro::Movimenti.new(libro); puts m.da_consegnare.count; puts m.completati.count; puts m.riepilogo_per_anno.inspect"`

**Step 3: Commit**

```bash
git add app/models/libro/movimenti.rb
git commit -m "feat: add Libro::Movimenti PORO for movement queries"
```

---

### Task 2: Add route and controller

**Files:**
- Modify: `config/routes.rb:287-299` (inside `resources :libri` block)
- Create: `app/controllers/libri/movimenti_controller.rb`

**Step 1: Add route**

In `config/routes.rb`, inside the existing `resources :libri do` block (line 287), add:

```ruby
resources :libri do
  collection do
    get 'crosstab'
    get 'scarico_fascicoli'
  end
  member do
    get 'get_prezzo_e_sconto'
    get 'fascicoli', to: 'confezionator#index'
    post 'fascicoli', to: 'confezionator#create', as: 'confezione'
    delete 'fascicoli', to: 'confezionator#destroy'
  end
  resource :movimenti, only: [:show], module: :libri
  resources :qrcodes
end
```

The new line is `resource :movimenti, only: [:show], module: :libri` — singular resource, generates `libro_movimenti_path(libro)`.

**Step 2: Create controller**

```ruby
# app/controllers/libri/movimenti_controller.rb
class Libri::MovimentiController < ApplicationController
  before_action :authenticate_user!

  def show
    @libro = Current.account.libri.friendly.find(params[:libro_id])
    @movimenti = Libro::Movimenti.new(@libro)
  end
end
```

**Step 3: Verify route**

Run: `docker exec prova-app-1 bin/rails routes -g movimenti`
Expected: `libro_movimenti GET /:account_id/libri/:libro_id/movimenti`

**Step 4: Commit**

```bash
git add config/routes.rb app/controllers/libri/movimenti_controller.rb
git commit -m "feat: add Libri::MovimentiController with route"
```

---

### Task 3: Create movimenti views (lazy-loaded frame)

**Files:**
- Create: `app/views/libri/movimenti/show.html.erb`
- Create: `app/views/libri/movimenti/_tabella_movimenti.html.erb` (reusable partial)
- Create: `app/views/libri/movimenti/_riepilogo.html.erb`

**Step 1: Create the reusable movimenti table partial**

```erb
<%# app/views/libri/movimenti/_tabella_movimenti.html.erb %>
<%# locals: (documento_righe:) -%>

<table class="txt-small full-width">
  <thead>
    <tr class="txt-subtle txt-x-small txt-uppercase">
      <th class="txt-start">Causale</th>
      <th class="txt-start">Cliente</th>
      <th class="txt-start">Documento</th>
      <th class="txt-end">Copie</th>
      <th class="txt-end">Importo</th>
    </tr>
  </thead>
  <tbody>
    <% documento_righe.each do |dr| %>
      <tr>
        <td class="txt-subtle"><%= dr.documento.causale %></td>
        <td class="overflow-ellipsis" style="max-width: 200px;">
          <% if dr.documento.clientable.present? && !dr.documento.clientable.is_a?(Domain::NessunCliente) %>
            <%= link_to truncate(dr.documento.clientable.denominazione, length: 30), dr.documento.clientable, class: "txt-link" %>
          <% end %>
        </td>
        <td>
          <%= link_to dr.documento.entry || dr.documento, class: "txt-link" do %>
            <%= dr.documento.causale %> #<%= dr.documento.numero_documento %>
          <% end %>
        </td>
        <td class="txt-end font-weight-bold"><%= dr.riga.quantita %></td>
        <td class="txt-end"><%= number_to_currency(dr.riga.importo) %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

**Step 2: Create the riepilogo crosstab partial**

```erb
<%# app/views/libri/movimenti/_riepilogo.html.erb %>
<%# locals: (riepilogo:) -%>

<% if riepilogo.any? %>
  <h3 class="divider divider--fade txt-medium font-weight-black">Riepilogo</h3>
  <table class="txt-small full-width">
    <thead>
      <tr class="txt-subtle txt-x-small txt-uppercase">
        <th class="txt-start">Anno</th>
        <th class="txt-end">Ordini</th>
        <th class="txt-end">Vendite</th>
        <th class="txt-end">Carichi</th>
        <th class="txt-end">Importo</th>
      </tr>
    </thead>
    <tbody>
      <% riepilogo.each do |anno, dati| %>
        <tr>
          <td class="font-weight-bold"><%= anno %></td>
          <td class="txt-end"><%= dati["ordine"].nonzero? || "-" %></td>
          <td class="txt-end"><%= dati["vendita"].nonzero? || "-" %></td>
          <td class="txt-end"><%= dati["carico"].nonzero? || "-" %></td>
          <td class="txt-end font-weight-bold"><%= number_to_currency(dati[:importo] / 100.0) %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

**Step 3: Create the main show view (turbo frame response)**

```erb
<%# app/views/libri/movimenti/show.html.erb %>

<%= turbo_frame_tag dom_id(@libro, :movimenti_lazy) do %>
  <%= render "libri/movimenti/riepilogo", riepilogo: @movimenti.riepilogo_per_anno %>

  <% completati = @movimenti.completati.to_a %>
  <% if completati.any? %>
    <% completati.group_by { |dr| dr.documento.data_documento&.year }
                 .sort_by { |anno, _| -anno.to_i }
                 .each do |anno, drs| %>
      <h4 class="divider divider--fade txt-small txt-subtle txt-uppercase">
        <%= anno %> <span class="txt-xx-small">(<%= drs.size %>)</span>
      </h4>
      <%= render "libri/movimenti/tabella_movimenti", documento_righe: drs %>
    <% end %>
  <% end %>
<% end %>
```

**Step 4: Commit**

```bash
git add app/views/libri/movimenti/
git commit -m "feat: add movimenti views with riepilogo crosstab and completati"
```

---

### Task 4: Update notch buttons (footer_display)

**Files:**
- Modify: `app/views/libri/container/_footer_display.html.erb`

**Step 1: Add Adozioni/Concorrenza button next to Modifica**

Replace the entire file content with:

```erb
<%# locals: (libro:) -%>

<div class="flex gap-half">
  <%= link_to edit_libro_path(libro), class: "btn",
      data: { turbo_method: :get, turbo_stream: true,
              controller: "hotkey", action: "keydown.e@document->hotkey#click" } do %>
    Modifica <kbd class="hide-on-touch">E</kbd>
  <% end %>

  <% if libro.adozioni_count.positive? && libro.codice_isbn.present? %>
    <%= link_to titolo_path(codice_isbn: libro.codice_isbn), class: "btn btn--ghost",
        data: { controller: "hotkey", action: "keydown.a@document->hotkey#click" } do %>
      Adozioni/Concorrenza <kbd class="hide-on-touch">A</kbd>
    <% end %>
  <% end %>
</div>
```

**Step 2: Commit**

```bash
git add app/views/libri/container/_footer_display.html.erb
git commit -m "feat: add Adozioni/Concorrenza button in libro notch"
```

---

### Task 5: Rewrite footer with movimenti and lazy frame

**Files:**
- Modify: `app/views/libri/container/_footer.html.erb` (full rewrite)
- Modify: `app/views/libri/show.html.erb` (pass movimenti)
- Modify: `app/controllers/libri_controller.rb:42-50` (add @movimenti)

**Step 1: Update controller to create Movimenti PORO**

In `app/controllers/libri_controller.rb`, update the `show` action:

```ruby
def show
  @giacenza = @libro.giacenza
  @movimenti = Libro::Movimenti.new(@libro)

  respond_to do |format|
    format.html
    format.turbo_stream
  end
end
```

Remove `@adozioni` — it's no longer needed (adozioni are on the titolo page).

**Step 2: Update show.html.erb to pass movimenti**

Replace the footer render in `app/views/libri/show.html.erb`:

```erb
<% @page_title = @libro.titolo %>
<% @header_class = "header--card" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <% info = referrer_back_info || { label: "Libri", path: libri_path } %>
    <%= back_link_to info[:label], info[:path] %>
  </div>

  <div class="header__actions header__actions--end">
  </div>
<% end %>

<div class="full-width card-grid pad group show-navigator">
  <%= render "libri/container/container", libro: @libro, giacenza: @giacenza %>
</div>

<div class="scuola-show" style="--card-color: <%= libro_sconto_color(@libro) %>;">
  <%= render "libri/container/footer", libro: @libro, movimenti: @movimenti %>
  <%= render "libri/container/confezionator", libro: @libro %>
</div>
```

Note: `_container.html.erb` also receives `adozioni:` — we need to remove that parameter from container and footer locals.

**Step 3: Update container partial to remove adozioni param**

In `app/views/libri/container/_container.html.erb`, change the locals declaration:

```erb
<%# locals: (libro:, giacenza:) -%>
```

(Remove `adozioni:` from the locals line — line 1 only.)

**Step 4: Rewrite footer**

Replace entire `app/views/libri/container/_footer.html.erb`:

```erb
<%# locals: (libro:, movimenti:) -%>

<div class="full-width">
  <%# Da consegnare — loaded immediately %>
  <% da_consegnare = movimenti.da_consegnare.to_a %>
  <% if da_consegnare.any? %>
    <h3 class="divider divider--fade txt-medium font-weight-black">
      Da consegnare (<%= da_consegnare.size %>)
    </h3>
    <%= render "libri/movimenti/tabella_movimenti", documento_righe: da_consegnare %>
  <% end %>

  <%# Riepilogo + Completati — lazy loaded %>
  <%= turbo_frame_tag dom_id(libro, :movimenti_lazy),
      src: libro_movimenti_path(libro),
      loading: :lazy do %>
    <p class="txt-small txt-subtle">Caricamento movimenti...</p>
  <% end %>
</div>
```

**Step 5: Verify the page loads**

Run: `docker exec prova-app-1 bin/rails test` (check no test failures from removed adozioni param)

**Step 6: Commit**

```bash
git add app/controllers/libri_controller.rb app/views/libri/show.html.erb app/views/libri/container/_container.html.erb app/views/libri/container/_footer.html.erb
git commit -m "feat: rewrite libro footer with movimenti and lazy-loaded riepilogo"
```

---

### Task 6: Fix any remaining references to removed adozioni param

**Files:**
- Check: `app/views/libri/container/_container.html.erb` — ensure `adozioni` is removed from locals
- Check: `app/views/libri/show.turbo_stream.erb` — may pass adozioni to container

**Step 1: Search for adozioni references in libro views**

Run: `grep -rn "adozioni" app/views/libri/`

Fix any remaining references that pass `adozioni:` to container or footer partials.

**Step 2: Test full page load in browser**

Navigate to a libro show page and verify:
- Notch shows "Modifica" + conditionally "Adozioni/Concorrenza"
- "Da consegnare" section appears immediately
- Lazy frame loads riepilogo crosstab + completati

**Step 3: Commit if fixes needed**

```bash
git add -u
git commit -m "fix: remove remaining adozioni references from libro views"
```
