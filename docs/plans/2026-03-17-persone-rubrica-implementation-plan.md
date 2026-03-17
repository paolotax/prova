# Persone Rubrica — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify persona views under a top-level `PersoneController` with full CRUD and a new index page (contact list with cards), eliminating duplication between `scuole/persone/` and `persone/`.

**Architecture:** Move all partials from `app/views/scuole/persone/` to `app/views/persone/`. Expand `PersoneController` to full CRUD (absorbing logic from `Scuole::PersoneController`). Move nested resources (persona_classi, classe_chips, saggi) under top-level `persone`. Reduce `Scuole::PersoneController` to `create` + `show` redirect. Add new index with card partial.

**Tech Stack:** Rails 8.1, Turbo Streams, Stimulus, Hotwire Combobox, `set_page_and_extract_portion_from` for pagination.

---

### Task 1: Update Routes

**Files:**
- Modify: `config/routes.rb:474-513`

**Step 1: Update routes**

Change the top-level `persone` from `only: [:show]` to full CRUD with nested resources. Reduce scuole-scoped persone to `only: [:show, :create]`.

```ruby
# Replace line 474:
#   resources :persone, only: [:show]
# With:
resources :persone, only: [:index, :show, :edit, :update, :create, :destroy] do
  resources :persona_classi, only: [:destroy], module: :persone
  resources :classe_chips, only: [:create], module: :persone, param: :combobox_value
  resources :saggi, only: [:create, :update, :destroy], module: :persone
end
```

Inside the `scuole` block, reduce persone to show + create only (remove edit, update, destroy). Keep nested persona_classi, classe_chips, saggi REMOVED from scuole scope (they move to top-level):

```ruby
# In the scuole scope module block, change:
#   resources :persone, only: [:show, :edit, :update, :create, :destroy] do
#     resources :persona_classi, only: [:destroy], module: :persone
#     resources :classe_chips, only: [:create], module: :persone, param: :combobox_value
#     resources :saggi, only: [:create, :update, :destroy], module: :persone
#   end
# To:
resources :persone, only: [:show, :create]
```

**Step 2: Verify routes compile**

Run: `docker exec prova-app-1 bin/rails routes | grep persona`
Expected: top-level CRUD routes + nested persona_classi, classe_chips, saggi under persone. Scuole::persone only show+create.

**Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: move persone CRUD routes to top-level, reduce scuole-scoped to show+create"
```

---

### Task 2: Move Partials from scuole/persone/ to persone/

**Files:**
- Move: `app/views/scuole/persone/*.erb` → `app/views/persone/`
- Move: `app/views/scuole/persone/display/` → `app/views/persone/display/`
- Move: `app/views/scuole/persone/container/` → `app/views/persone/container/`
- Keep: `app/views/scuole/persone/create.turbo_stream.erb` (scuola-context create)
- Delete: `app/views/scuole/persone/` remaining files after move

**Step 1: Move files**

```bash
# Move main partials
mv app/views/scuole/persone/_container.html.erb app/views/persone/
mv app/views/scuole/persone/_content_display.html.erb app/views/persone/
mv app/views/scuole/persone/_edit_form.html.erb app/views/persone/
mv app/views/scuole/persone/_search_dialog.html.erb app/views/persone/
mv app/views/scuole/persone/_footer.html.erb app/views/persone/
mv app/views/scuole/persone/_edit_footer.html.erb app/views/persone/

# Move subdirectories
mv app/views/scuole/persone/display app/views/persone/
mv app/views/scuole/persone/container app/views/persone/

# Move turbo_stream templates (edit and show go to top-level, create stays)
mv app/views/scuole/persone/edit.turbo_stream.erb app/views/persone/
mv app/views/scuole/persone/show.turbo_stream.erb app/views/persone/

# Delete old show.html.erb (will be replaced)
rm app/views/scuole/persone/show.html.erb
```

**Step 2: Update partial references inside moved files**

In `app/views/persone/_container.html.erb`, update all `render "scuole/persone/..."` to `render "persone/..."`:

- `"scuole/persone/display/perma/board"` → `"persone/display/perma/board"`
- `"scuole/persone/content_display"` → `"persone/content_display"`
- `"scuole/persone/footer"` → `"persone/footer"`
- `"scuole/persone/container/appunti"` → `"persone/container/appunti"`
- `"scuole/persone/container/saggi"` → `"persone/container/saggi"`

In `app/views/persone/edit.turbo_stream.erb`, update:
- `"scuole/persone/edit_form"` → `"persone/edit_form"`
- `"scuole/persone/edit_footer"` → `"persone/edit_footer"`

In `app/views/persone/show.turbo_stream.erb`, update:
- `"scuole/persone/content_display"` → `"persone/content_display"`
- `"scuole/persone/footer"` → `"persone/footer"`

In `app/views/scuole/container/_insegnanti.html.erb`, update:
- `"scuole/persone/search_dialog"` → `"persone/search_dialog"` (2 occurrences)

**Step 3: Commit**

```bash
git add -A
git commit -m "refactor: move persone partials from scuole/persone/ to persone/"
```

---

### Task 3: Update Path Helpers in Moved Partials

All path helpers that reference `scuola_persona_path` must change to `persona_path`. This is the most pervasive change.

**Files:**
- Modify: `app/views/persone/_container.html.erb`
- Modify: `app/views/persone/_footer.html.erb`
- Modify: `app/views/persone/_edit_footer.html.erb`
- Modify: `app/views/persone/_edit_form.html.erb`
- Modify: `app/views/persone/_content_display.html.erb`
- Modify: `app/views/persone/container/_saggi.html.erb`
- Modify: `app/views/persone/display/perma/_board.html.erb`
- Modify: `app/views/scuole/container/_insegnanti.html.erb`
- Modify: `app/views/scuole/classi/_docenti.html.erb`

**Step 1: Update `_container.html.erb`**

Remove `scuola` from locals declaration — change `<%# locals: (persona:, scuola:, appunti:) -%>` to `<%# locals: (persona:, appunti:) -%>`.

Derive scuola from persona: add `<% scuola = persona.scuola %>` at top.

Update path helpers:
- `scuola_persona_path(scuola, @prev_persona_id)` → `persona_path(@prev_persona_id)`
- `scuola_persona_path(scuola, @next_persona_id)` → `persona_path(@next_persona_id)`
- `scuola_persona_path(scuola, persona)` → `persona_path(persona)` (in delete section)

Update sub-partial renders to remove `scuola:` local where not needed, or keep it where the partial still uses it (edit_form, content_display, saggi still need scuola for classi/adozioni).

For `_board.html.erb`, `_content_display.html.erb`, `_edit_form.html.erb`, `_footer.html.erb`, `_edit_footer.html.erb`, and `container/_saggi.html.erb`: keep passing `scuola: scuola` since they use scuola for domain logic (classi, adozioni, materie). But handle nil scuola gracefully.

**Step 2: Update `_footer.html.erb`**

Change:
```erb
<%# locals: (persona:, scuola:) -%>

<%= link_to edit_scuola_persona_path(scuola, persona), class: "btn", ...
```
To:
```erb
<%# locals: (persona:) -%>

<%= link_to edit_persona_path(persona), class: "btn", ...
```

**Step 3: Update `_edit_footer.html.erb`**

Change:
```erb
<%# locals: (persona:, scuola:) -%>

<%= button_tag class: "btn btn--positive", type: :submit, form: dom_id(persona, :edit_form), ... %>
  Salva <kbd class="hide-on-touch">S</kbd>
<% end %>

<%= link_to scuola_persona_path(scuola, persona), class: "btn btn--reversed", ...
```
To:
```erb
<%# locals: (persona:) -%>

<%= button_tag class: "btn btn--positive", type: :submit, form: dom_id(persona, :edit_form), ... %>
  Salva <kbd class="hide-on-touch">S</kbd>
<% end %>

<%= link_to persona_path(persona), class: "btn btn--reversed", ...
```

**Step 4: Update `_edit_form.html.erb`**

Change form url:
```erb
<%# locals: (persona:, scuola:) -%>
<%= form_with model: persona, url: scuola_persona_path(scuola, persona), ...
```
To:
```erb
<%# locals: (persona:) -%>
<% scuola = persona.scuola %>
<%= form_with model: persona, url: persona_path(persona), ...
```

The materie_esistenti query uses `scuola.persone...` — guard with `if scuola`:
```erb
<% materie_esistenti = scuola ? scuola.persone.joins(:persona_classi)... : [] %>
```

The classi combobox uses `scuola.classi` and `scuola_persona_classe_chips_path` — change to:
```erb
<%= combobox_tag "persona[classe_ids]",
    hw_combobox_options(scuola ? scuola.classi.order(:anno_corso, :sezione) : Classe.none, display: :nome_breve),
    value: persona.classe_ids.join(","),
    multiselect_chip_src: persona_classe_chips_path(persona),
    ...
```

**Step 5: Update `_content_display.html.erb`**

Change locals: remove `scuola:`, derive from persona:
```erb
<%# locals: (persona:) -%>
<% scuola = persona.scuola %>
```

Guard scuola-dependent code (tipo_scuola, classi, adozioni, badge_styles) with `if scuola`:
```erb
<% if scuola %>
  <% tipo_scuola = scuola.classi.pick(:tipo_scuola) || "MM" %>
  ... (all the cattedra/adozione/badge logic)
<% end %>
```

Update `classi_badge_links` call — change `classi_badge_links(classi, scuola, ...)` to pass nil-safe scuola.

**Step 6: Update `container/_saggi.html.erb`**

Change locals and paths:
```erb
<%# locals: (persona:) -%>
<% scuola = persona.scuola %>
```

All `scuola_persona_saggio_path(scuola, persona, saggio)` → `persona_saggio_path(persona, saggio)`.
`scuola_persona_saggi_path(scuola, persona)` → `persona_saggi_path(persona)`.

Guard `saggi = persona.saggi.per_scuola(scuola)` — if scuola nil, show all saggi:
```erb
<% saggi = scuola ? persona.saggi.per_scuola(scuola).includes(:libro) : persona.saggi.includes(:libro) %>
```

**Step 7: Update `display/perma/_board.html.erb`**

Change locals, derive scuola:
```erb
<%# locals: (persona:) -%>
<% scuola = persona.scuola %>

<div id="<%= dom_id(persona, :board) %>">
  <%= render "shared/cards/display/common/board",
      id: persona.ruolo&.titleize,
      name: scuola&.denominazione %>
</div>
```

**Step 8: Update `_insegnanti.html.erb`**

Change `scuola_persona_path(scuola, persona)` → `persona_path(persona)` (3 occurrences: line 97, 119, and any others).

**Step 9: Update `_docenti.html.erb`**

Change `scuola_persona_path(scuola, persona)` → `persona_path(persona)` (line 8).

**Step 10: Update turbo_stream templates**

In `app/views/persone/edit.turbo_stream.erb`:
```erb
<%= turbo_stream.replace [@persona, :edit] do %>
  <%= turbo_frame_tag @persona, :edit do %>
    <%= render "persone/edit_form", persona: @persona %>
  <% end %>
<% end %>

<%= turbo_stream.replace [@persona, :footer] do %>
  <%= turbo_frame_tag @persona, :footer do %>
    <%= render "persone/edit_footer", persona: @persona %>
  <% end %>
<% end %>
```

In `app/views/persone/show.turbo_stream.erb`:
```erb
<%= turbo_stream.replace [@persona, :edit] do %>
  <%= turbo_frame_tag @persona, :edit do %>
    <%= render "persone/content_display", persona: @persona %>
  <% end %>
<% end %>

<%= turbo_stream.replace [@persona, :footer] do %>
  <%= turbo_frame_tag @persona, :footer do %>
    <%= render "persone/footer", persona: @persona %>
  <% end %>
<% end %>
```

**Step 11: Update `_container.html.erb` render calls**

Remove `scuola: scuola` from all sub-partial render calls since they now derive scuola from persona:
```erb
<%= render "persone/display/perma/board", persona: persona %>
<%= render "persone/content_display", persona: persona %>
<%= render "persone/footer", persona: persona %>
<%= render "persone/container/appunti", appunti: appunti %>
<%= render "persone/container/saggi", persona: persona %>
<%= render "shared/container/delete", record: persona, path: persona_path(persona), label: persona.nome_completo %>
```

**Step 12: Commit**

```bash
git add -A
git commit -m "refactor: update path helpers from scuola_persona to persona in all partials"
```

---

### Task 4: Expand PersoneController with Full CRUD

**Files:**
- Modify: `app/controllers/persone_controller.rb`
- Modify: `app/controllers/scuole/persone_controller.rb`

**Step 1: Rewrite PersoneController**

Replace `app/controllers/persone_controller.rb` with full CRUD, absorbing logic from `Scuole::PersoneController`:

```ruby
class PersoneController < ApplicationController
  before_action :set_persona, except: [:index, :create]

  def index
    @persone = Current.account.persone
                               .includes(:scuola, :classi)
                               .order(:cognome, :nome)
    @total_count = @persone.count
    set_page_and_extract_portion_from @persone
  end

  def show
    load_prev_next
    @appunti = @persona.appunti.includes(entry: [:goldness, :closure, :not_now]).order(created_at: :desc)

    respond_to do |format|
      format.html
      format.turbo_stream
      format.json do
        render json: {
          id: @persona.id,
          cognome: @persona.cognome,
          nome: @persona.nome,
          email: @persona.email,
          cellulare: @persona.cellulare,
          ruolo: @persona.ruolo,
          materia: @persona.persona_classi.where.not(materia: nil).pick(:materia),
          classe_ids: @persona.classe_ids
        }
      end
    end
  end

  def create
    p = params[:persona] || params
    @persona = Current.account.persone.new(
      cognome: p[:cognome],
      nome: p[:nome],
      ruolo: p[:ruolo].presence || :docente,
      email: p[:email],
      cellulare: p[:cellulare],
      scuola_id: p[:scuola_id]
    )

    if @persona.save
      redirect_to persona_path(@persona), notice: "#{@persona.nome_completo} aggiunto"
    else
      redirect_back fallback_location: persone_path, alert: @persona.errors.full_messages.join(", ")
    end
  end

  def edit
    respond_to do |format|
      format.html { redirect_to persona_path(@persona) }
      format.turbo_stream
    end
  end

  def update
    sync_classi if params[:classe_ids].present? || params.dig(:persona, :classe_ids).present?
    materia_val = params.dig(:persona, :materia) || params[:materia]
    update_materia(materia_val) if materia_val.present?

    if @persona.update(persona_params.except(:classe_ids, :materia))
      if params[:return_to] == "scuola" && @persona.scuola.present?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(@persona.scuola, :insegnanti),
              partial: "scuole/container/insegnanti",
              locals: { scuola: @persona.scuola.reload }
            )
          end
          format.html { redirect_to scuola_path(@persona.scuola), notice: "#{@persona.nome_completo} aggiornato" }
        end
        return
      end

      redirect_to persona_path(@persona)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    nome = @persona.nome_completo
    scuola = @persona.scuola
    @persona.destroy

    if scuola.present?
      redirect_to scuola_path(scuola), notice: "#{nome} eliminato"
    else
      redirect_to persone_path, notice: "#{nome} eliminato"
    end
  end

  private

  def set_persona
    @persona = Current.account.persone.find(params[:id])
  end

  def persona_params
    permitted = params.require(:persona).permit(:nome, :cognome, :cellulare, :email, :telefono, :note, :ruolo, :scuola_id, :classe_ids, :materia)
    if permitted[:classe_ids].is_a?(String)
      permitted[:classe_ids] = permitted[:classe_ids].split(",").reject(&:blank?)
    end
    permitted
  end

  def update_materia(materia)
    @persona.persona_classi.update_all(materia: materia)
  end

  def sync_classi
    raw = params[:classe_ids] || params.dig(:persona, :classe_ids)
    new_ids = raw.to_s.split(",").reject(&:blank?)
    current_ids = @persona.classe_ids.map(&:to_s)
    cattedra = @persona.persona_classi.where.not(materia: nil).pick(:materia)

    (current_ids - new_ids).each do |id|
      @persona.persona_classi.find_by(classe_id: id)&.destroy
    end

    (new_ids - current_ids).each do |id|
      @persona.persona_classi.create(classe_id: id, materia: cattedra)
    end
  end

  def load_prev_next
    scope = Current.account.persone.order(:cognome, :nome)
    all_ids = scope.pluck(:id)
    idx = all_ids.index(@persona.id)
    @prev_persona_id = idx && idx > 0 ? all_ids[idx - 1] : nil
    @next_persona_id = idx && idx < all_ids.size - 1 ? all_ids[idx + 1] : nil
  end
end
```

**Step 2: Reduce Scuole::PersoneController**

Replace `app/controllers/scuole/persone_controller.rb` with:

```ruby
module Scuole
  class PersoneController < ApplicationController
    before_action :set_scuola

    def show
      redirect_to persona_path(params[:id])
    end

    def create
      p = params[:persona] || params
      @persona = @scuola.persone.new(
        cognome: p[:cognome],
        nome: p[:nome],
        ruolo: p[:ruolo].presence || :docente,
        email: p[:email],
        cellulare: p[:cellulare],
        account: Current.account
      )

      if @persona.save
        classe_ids = params[:classe_ids].to_s.split(",").reject(&:blank?)
        target_classi = classe_ids.any? ? @scuola.classi.where(id: classe_ids) : @scuola.classi
        materia = (p[:materia] || params[:materia]).presence

        target_classi.each do |classe|
          @persona.persona_classi.create(classe: classe, materia: materia)
        end

        respond_to do |format|
          format.turbo_stream
          format.html { redirect_to scuola_path(@scuola), notice: "#{@persona.nome_completo} aggiunto" }
        end
      else
        redirect_to scuola_path(@scuola), alert: @persona.errors.full_messages.join(", ")
      end
    end

    private

    def set_scuola
      @scuola = Scuola.find(params[:scuola_id])
    end
  end
end
```

**Step 3: Commit**

```bash
git add app/controllers/persone_controller.rb app/controllers/scuole/persone_controller.rb
git commit -m "feat: expand PersoneController with full CRUD, reduce Scuole::PersoneController to create+redirect"
```

---

### Task 5: Move Nested Controllers to Top-Level Persone Module

**Files:**
- Create: `app/controllers/persone/persona_classi_controller.rb`
- Create: `app/controllers/persone/classe_chips_controller.rb`
- Create: `app/controllers/persone/saggi_controller.rb`
- Delete: `app/controllers/scuole/persone/persona_classi_controller.rb`
- Delete: `app/controllers/scuole/persone/classe_chips_controller.rb`
- Delete: `app/controllers/scuole/persone/saggi_controller.rb`

**Step 1: Create `app/controllers/persone/persona_classi_controller.rb`**

```ruby
module Persone
  class PersonaClassiController < ApplicationController
    before_action :set_persona

    def destroy
      @persona_classe = @persona.persona_classi.find(params[:id])
      @persona_classe.destroy

      redirect_to persona_path(@persona), notice: "Classe scollegata"
    end

    private

    def set_persona
      @persona = Current.account.persone.find(params[:persona_id])
    end
  end
end
```

**Step 2: Create `app/controllers/persone/classe_chips_controller.rb`**

```ruby
module Persone
  class ClasseChipsController < ApplicationController
    def create
      @classi = Classe.where(id: params[:combobox_values].split(","))
      render turbo_stream: helpers.combobox_selection_chips_for(@classi, display: :nome_breve)
    end
  end
end
```

**Step 3: Create `app/controllers/persone/saggi_controller.rb`**

```ruby
class Persone::SaggiController < ApplicationController
  before_action :authenticate_user!
  before_action :set_persona
  before_action :set_saggio, only: [:update, :destroy]

  def create
    @saggio = @persona.saggi.build(saggio_params)
    @saggio.scuola = @persona.scuola

    if @saggio.save
      redirect_to persona_path(@persona)
    else
      redirect_to persona_path(@persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def update
    if @saggio.update(saggio_params)
      redirect_to persona_path(@persona)
    else
      redirect_to persona_path(@persona), alert: @saggio.errors.full_messages.join(", ")
    end
  end

  def destroy
    @saggio.destroy
    redirect_to persona_path(@persona)
  end

  private

  def set_persona
    @persona = Current.account.persone.find(params[:persona_id])
  end

  def set_saggio
    @saggio = @persona.saggi.find(params[:id])
  end

  def saggio_params
    params.require(:saggio).permit(:libro_id, :quantita, :stato, :note)
  end
end
```

**Step 4: Delete old scuole-scoped controllers**

```bash
rm app/controllers/scuole/persone/persona_classi_controller.rb
rm app/controllers/scuole/persone/classe_chips_controller.rb
rm app/controllers/scuole/persone/saggi_controller.rb
rmdir app/controllers/scuole/persone/ 2>/dev/null || true
```

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor: move persona nested controllers from scuole/persone/ to persone/ module"
```

---

### Task 6: Update show.html.erb for Top-Level Persone

**Files:**
- Modify: `app/views/persone/show.html.erb`

**Step 1: Rewrite show.html.erb**

Replace the simple existing show with the full-featured version:

```erb
<% @page_title = @persona.nome_completo %>
<% @header_class = "header--card" %>

<% content_for :header do %>
  <div class="header__actions header__actions--start">
    <% if @persona.scuola.present? %>
      <%= back_link_to_url @persona.scuola.denominazione.capitalize, scuola_path(@persona.scuola) %>
    <% else %>
      <%= back_link_to_url "Persone", persone_path %>
    <% end %>
  </div>
<% end %>

<div class="full-width pad group">
  <%= render "persone/container", persona: @persona, appunti: @appunti %>
</div>
```

**Step 2: Commit**

```bash
git add app/views/persone/show.html.erb
git commit -m "feat: update persone show page with full container and smart back link"
```

---

### Task 7: Create Index Page and Card Partial

**Files:**
- Create: `app/views/persone/index.html.erb`
- Create: `app/views/persone/_persona.html.erb`

**Step 1: Create card partial `_persona.html.erb`**

Following the pattern from `_cliente.html.erb`:

```erb
<%# locals: (persona:) -%>

<%= tag.article id: dom_id(persona),
    class: "card",
    style: "--card-color: #{persona.scuola ? tipo_scuola_color(persona.scuola.tipo_scuola) : 'var(--color-subtle)'}",
    tabindex: 0,
    data: { navigable_list_target: "item", action: "mouseenter->navigable-list#hoverSelect" } do %>

  <div class="flex flex-column flex-item-grow max-inline-size">
    <%= link_to persona_path(persona), class: "card__link", data: { turbo_frame: "_top" } do %>
      <span class="for-screen-reader"><%= persona.nome_completo %></span>
    <% end %>

    <header class="card__header">
      <div class="card__board">
        <span class="card__id"><%= persona.ruolo&.upcase.presence || "PERSONA" %></span>
        <span class="card__board-name"><%= persona.scuola&.denominazione %></span>
      </div>
    </header>

    <div class="card__body">
      <div class="card__content">
        <h3 class="card__title overflow-line-clamp" style="--lines: 2;">
          <%= persona.nome_completo %>
        </h3>
        <div class="margin-block-start-half txt-xx-small txt-subtle flex flex-column gap-quarter">
          <% if persona.cellulare.present? %>
            <span class="margin-inline-start"><%= icon_tag "phone", class: "icon--small" %> <%= persona.cellulare %></span>
          <% end %>
          <% if persona.email.present? %>
            <span class="margin-inline-start"><%= icon_tag "envelope", class: "icon--small" %> <%= persona.email %></span>
          <% end %>
          <% if persona.classi.any? %>
            <span class="margin-inline-start"><%= icon_tag "academic-cap", class: "icon--small" %> <%= persona.classi.size %> classi</span>
          <% end %>
        </div>
      </div>
    </div>
  </div>

<% end %>
```

**Step 2: Create index page `index.html.erb`**

Following the pattern from `clienti/index.html.erb`:

```erb
<% @page_title = "Persone" %>
<% @body_class = "contained-scrolling" %>

<% content_for :header do %>
  <h1 class="header__title divider divider--fade full-width">
    <span class="overflow-ellipsis">Persone</span>
  </h1>
<% end %>

<%= turbo_frame_tag :search_results do %>
  <% if @page.used? %>
    <p class="txt-small txt-subtle margin-block-end-half">
      <%= @total_count %> <%= @total_count == 1 ? "persona trovata" : "persone trovate" %>
    </p>

    <div class="cards cards--grid">
      <%= with_automatic_pagination :persone, @page,
          class: "cards__list",
          data: { controller: "navigable-list",
              navigable_list_auto_select_value: false,
              navigable_list_actionable_items_value: true,
              navigable_list_prevent_handled_keys_value: true,
              action: "keydown->navigable-list#navigate" } do %>
        <%= render @page.records %>
      <% end %>
    </div>
  <% else %>
    <%= blank_slate_for(:persone) %>
  <% end %>
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/persone/index.html.erb app/views/persone/_persona.html.erb
git commit -m "feat: add persone index page with card partial for contact list"
```

---

### Task 8: Update Search Dialog for Scuola Context

The `_search_dialog.html.erb` now lives in `persone/` but is rendered from scuola context (`_insegnanti.html.erb`). The form URL and search URL need to stay scuola-scoped when called from scuola context.

**Files:**
- Verify: `app/views/persone/_search_dialog.html.erb` — already accepts `form_url` and `select_url` as locals with defaults
- Verify: `app/views/scuole/container/_insegnanti.html.erb` — already renders with `scuola:` local

**Step 1: Verify the search dialog already uses local variables for URLs**

The `_search_dialog.html.erb` already has:
```erb
<%# locals: (scuola:, form_url: nil, select_url: nil, assign_url: nil, ruolo: nil) -%>
<% form_url ||= scuola_persone_path(scuola) %>
<% select_url ||= scuola_persona_path(scuola, '__PERSONA_ID__') %>
```

This is already flexible — it uses scuola routes by default but can be overridden. No changes needed to the dialog itself since it's always called from scuola context.

**Step 2: Verify `_insegnanti.html.erb` renders correctly**

The render call `<%= render "persone/search_dialog", scuola: scuola %>` passes `scuola:` which the dialog uses for its default URLs. This should work.

**Step 3: Verify and test**

Run: `docker exec prova-app-1 bin/rails routes | grep persona`
Verify routes resolve correctly.

**Step 4: Commit (if any changes needed)**

---

### Task 9: Smoke Test

**Step 1: Run existing tests**

Run: `docker exec prova-app-1 bin/rails test`
Fix any failures from path helper changes.

**Step 2: Manual verification checklist**

- Visit `/persone` — should show card list of all persone
- Visit `/persone/:id` — should show full persona card with classi, adozioni, contatti
- Edit a persona from show page — edit form loads via turbo_stream
- Save persona — redirects back to show
- Delete persona — redirects to scuola (if has one) or persone index
- Visit `/scuole/:id` — insegnanti section shows, links go to `/persone/:id`
- From scuola, add new persona via search dialog — creates and refreshes insegnanti
- Visit `/scuole/:id/persone/:id` — redirects to `/persone/:id`

**Step 3: Commit any test fixes**

```bash
git add -A
git commit -m "fix: update tests for persone route changes"
```
