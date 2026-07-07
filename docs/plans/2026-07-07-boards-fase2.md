# Boards Fase 2 (Board multiple) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Board multiple per account: CRUD board, kanban per board, nuova card multi-tipo pilotata da `entry_types`, spostamento entry tra board.

**Architecture:** Il kanban del dashboard si generalizza in `BoardsController#show`; `/dashboard` diventa `boards#default` (la board default). I sub-controller colonne migrano da `dashboard/columns` a `boards/columns`. La creazione di appunti/documenti/tappe resta invariata: la board arriva via `params[:board_id]` e l'entry viene spostata con `Entry#move_to` dopo il save.

**Tech Stack:** Rails 8.1, Turbo (morph + frames), Stimulus esistenti (drag-and-drop invariato), Minitest + fixtures.

**Prerequisito:** Fase 1 completata e verde (`docs/plans/2026-07-07-boards-fase1.md`): tabella `boards`, `board_id` su columns/entries, `Account#default_board`, fixtures `boards.yml`.

**Regole di contesto:** identiche alla Fase 1 (comandi nel container `prova-app-1`, niente FK, branch corrente, commit mirati, niente anticipi di Fase 3/4 — `accesses` e link pubblico NON esistono ancora: in questa fase ogni board è visibile a tutti i membri dell'account).

---

### Task 0: Pre-flight

**Step 1:** `git status --short` pulito (o solo file di questo piano).
**Step 2:** `docker exec prova-app-1 bin/rails test test/models/board_test.rb test/models/entry_test.rb test/models/column_test.rb` → verde.
**Step 3:** Leggi come sono strutturati i test controller esistenti (autenticazione/sign-in, account nel path):

Run: `ls test/controllers/ && head -40 $(ls test/controllers/*_test.rb | head -1)`

Usa lo stesso pattern (helper di login, `account_id` nei path) in tutti i test controller di questo piano.

---

### Task 1: Rotte + BoardsController con CRUD e kanban

**Files:**
- Modify: `config/routes.rb` (sezione TRIAGE SYSTEM, dentro `scope '/:account_id'`)
- Create: `app/controllers/boards_controller.rb`
- Create: `app/views/boards/show.html.erb`, `app/views/boards/new.html.erb`, `app/views/boards/edit.html.erb`, `app/views/boards/_form.html.erb`
- Move/adapt: `app/views/dashboard/filtered_results.html.erb` → `app/views/boards/filtered_results.html.erb`; `app/views/dashboard/index.turbo_stream.erb` → `app/views/boards/show.turbo_stream.erb`
- Delete (a fine task): `app/controllers/dashboard_controller.rb`, `app/views/dashboard/index.html.erb`
- Test: `test/controllers/boards_controller_test.rb`

**Step 1: Scrivi i test (falliranno)** — adatta il pattern di autenticazione rilevato nel Task 0:

```ruby
# frozen_string_literal: true

require "test_helper"

class BoardsControllerTest < ActionDispatch::IntegrationTest
  # setup: sign-in come users(:one) su accounts(:fizzy), stile dei test esistenti

  test "dashboard mostra la board default" do
    get dashboard_path(account_id: accounts(:fizzy).id)
    assert_response :success
  end

  test "show di una board specifica" do
    get board_path(boards(:consegne_fizzy), account_id: accounts(:fizzy).id)
    assert_response :success
  end

  test "create crea una board con entry_types scelti" do
    assert_difference "Board.count" do
      post boards_path(account_id: accounts(:fizzy).id),
           params: { board: { name: "Fatture", entry_types: [ "Documento" ] } }
    end
    assert_equal [ "Documento" ], Board.order(:created_at).last.entry_types
  end

  test "destroy di una board non default" do
    board = boards(:consegne_fizzy)
    assert_difference "Board.count", -1 do
      delete board_path(board, account_id: accounts(:fizzy).id)
    end
  end

  test "destroy della board default è rifiutata" do
    assert_no_difference "Board.count" do
      delete board_path(boards(:dashboard_fizzy), account_id: accounts(:fizzy).id)
    end
  end
end
```

**Step 2: Run** `docker exec prova-app-1 bin/rails test test/controllers/boards_controller_test.rb` → FAIL (rotte inesistenti).

**Step 3: Rotte** — in `config/routes.rb` sostituisci il blocco dashboard:

```ruby
    # Unified triage dashboard → board di default
    get 'dashboard', to: 'boards#default'

    resources :boards do
      scope module: :boards do
        resources :columns, only: :show
        namespace :columns do
          resource :postponed, only: :show
          resource :closed, only: :show
        end
      end
    end
```

e cambia la root account: `root 'boards#default', as: :account_root`. Rimuovi il vecchio `namespace :dashboard`. NON toccare le rotte `entries/*` né `columns/*` (left/right position).

Nota: `dashboard_path` continua a esistere come helper (stessa URL), quindi i link esistenti nelle viste non si rompono.

**Step 4: Controller** — `app/controllers/boards_controller.rb` (il kanban è l'attuale `DashboardController#index` generalizzato):

```ruby
# frozen_string_literal: true

class BoardsController < ApplicationController
  include FilterScoped
  include ScopesOwnTappe

  FILTER_PARAMS = ::Filters::EntryFilter::Fields::PERMITTED_PARAMS

  before_action :set_board, only: %i[show edit update destroy]

  def default
    @board = current_account.default_board
    render_board
  end

  def index
    @boards = current_account.boards.ordered
  end

  def show
    render_board
  end

  def new
    @board = current_account.boards.build
  end

  def create
    @board = current_account.boards.create!(board_params)
    redirect_to board_path(@board), notice: "Board creata."
  end

  def edit
  end

  def update
    @board.update!(board_params)
    redirect_to board_path(@board), notice: "Board aggiornata."
  end

  def destroy
    if @board.destroy
      redirect_to dashboard_path, notice: "Board eliminata. Le card sono tornate al dashboard."
    else
      redirect_to board_path(@board), alert: @board.errors.full_messages.to_sentence
    end
  end

  private

  def set_board
    @board = current_account.boards.find(params[:id])
  end

  def board_params
    params.require(:board).permit(:name, entry_types: [])
  end

  def render_board
    base_scope = @board.entries.published.then { |s| filter_own_tappe(s) }

    if @filter.used?
      filtered_scope = @filter.entries(base_scope)
                              .includes(:column, :goldness, :closure, :not_now)
                              .with_golden_first
                              .recent
      @total_count = filtered_scope.count
      set_page_and_extract_portion_from filtered_scope
      Entry.load_entryables(@page.records)
      render :filtered_results
    else
      @columns = @board.columns.ordered

      awaiting_triage_scope = base_scope.awaiting_triage
                                        .includes(:goldness, :closure, :not_now)
                                        .with_golden_first
                                        .recent
      @total_count = awaiting_triage_scope.count
      set_page_and_extract_portion_from awaiting_triage_scope
      Entry.load_entryables(@page.records)

      @postponed_count = base_scope.postponed.count
      @closed_count = base_scope.closed.count
      @column_counts = @columns.each_with_object({}) do |column, hash|
        hash[column.id] = base_scope.active.in_column(column).count
      end

      respond_to do |format|
        format.html { render :show }
        format.turbo_stream { render :show }
      end
    end
  end

  def filter_class
    ::Filters::EntryFilter
  end

  def filtering_class
    ::Filters::EntryFilter::Filtering
  end
end
```

Attenzione: verifica come `FilterScoped` risolve il filtro (convenzione sul nome del controller) — se `default`/`show` non attivano `@filter`, replica ciò che faceva `DashboardController` (stesso `FILTER_PARAMS`, stessi override privati).

**Step 5: Viste** — `app/views/boards/show.html.erb` è l'attuale `dashboard/index.html.erb` con la board:

```erb
<% @body_class = "contained-scrolling" %>
<%= render "filters/settings",
    filter_url: @board.default? ? dashboard_path : board_path(@board),
    user_filtering: @user_filtering,
    no_filtering_url: @board.default? ? dashboard_path : board_path(@board),
    filter_type: "entry_filter" %>

<%= turbo_frame_tag :search_results do %>
  <div id="cards_container">
    <%= render "shared/board_tools", board: @board %>
    <%= render "shared/kanban_board",
      board: @board,
      columns: @columns,
      column_counts: @column_counts,
      postponed_count: @postponed_count,
      closed_count: @closed_count %>
  </div>
<% end %>
```

(`board_tools` e `kanban_board` diventano board-aware nei Task 2 e 5 — fino ad allora passare il locale in più non rompe nulla se aggiorni le firme `locals:` insieme.)

`_form.html.erb` minimale (name + checkbox dei tipi, classi CSS Fizzy-style come le form esistenti — guarda `app/views/columns/_form.html.erb` per i pattern):

```erb
<%= form_with model: board do |form| %>
  <%= form.label :name, "Nome" %>
  <%= form.text_field :name, class: "input", required: true %>

  <fieldset>
    <legend>Tipi di card</legend>
    <% Entry.entryable_types.each do |type| %>
      <label>
        <%= check_box_tag "board[entry_types][]", type,
              board.entry_types.include?(type), id: "board_entry_types_#{type.downcase}" %>
        <%= type %>
      </label>
    <% end %>
  </fieldset>

  <%= form.submit "Salva", class: "btn" %>
<% end %>
```

Sposta `filtered_results.html.erb` e il turbo_stream da `app/views/dashboard/` a `app/views/boards/`, adattando i riferimenti a `@board`. Elimina `DashboardController` e `app/views/dashboard/index.html.erb` SOLO dopo che il Task 2 ha migrato i sub-controller colonne.

**Step 6: Run** i test del Task 1 → PASS (il kanban di show può ancora appoggiarsi ai partial vecchi finché il Task 2 non li migra: se `_kanban_board` esplode sui path `dashboard_columns_*`, tienili in rotta temporaneamente e rimuovili nel Task 2).

**Step 7: Commit**

```bash
git add config/routes.rb app/controllers/boards_controller.rb app/views/boards/ test/controllers/boards_controller_test.rb
git commit -m "feat(boards): CRUD board e kanban generalizzato per board

/dashboard diventa boards#default (board default dell'account).
BoardsController#show generalizza il vecchio DashboardController.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Sub-controller colonne sotto le board + kanban partial board-aware

**Files:**
- Create: `app/controllers/boards/columns_controller.rb`, `app/controllers/boards/columns/postponeds_controller.rb`, `app/controllers/boards/columns/closeds_controller.rb` (adattati dagli attuali `dashboard/columns/*`)
- Modify: `app/views/shared/_kanban_board.html.erb`
- Move: viste `app/views/dashboard/columns/*` → `app/views/boards/columns/*`
- Delete: `app/controllers/dashboard_controller.rb`, `app/controllers/dashboard/`, `app/views/dashboard/`

**Step 1: Controller** — esempio `app/controllers/boards/columns_controller.rb` (gli altri due sono analoghi, partendo dagli attuali `postponeds/closeds`):

```ruby
# frozen_string_literal: true

class Boards::ColumnsController < ApplicationController
  include ScopesOwnTappe

  before_action :set_board
  before_action :set_column

  def show
    set_page_and_extract_portion_from filter_own_tappe(
      @board.entries
            .published
            .active
            .in_column(@column)
            .includes(:goldness, :closure, :not_now)
            .with_golden_first
            .recent
    )
    Entry.load_entryables(@page.records)
  end

  private

  def set_board
    @board = current_account.boards.find(params[:board_id])
  end

  def set_column
    @column = @board.columns.find(params[:id])
  end
end
```

`postponeds`/`closeds`: stesso `set_board`, scope `@board.entries.published.postponed` / `.closed.recently_closed_first` (copia gli scope esatti dagli attuali controller prima di cancellarli).

**Step 2: Kanban partial** — `shared/_kanban_board.html.erb`, firma e path:

```erb
<%# locals: (board:, columns:, column_counts:, postponed_count:, closed_count:) -%>
```

- riga 5: `collapsible_columns_board_value: dom_id(board)` (così lo stato collapse è per-board)
- riga 47: `turbo_frame_tag :postponed_column, src: board_columns_postponed_path(board), ...`
- riga 124: `turbo_frame_tag :closed_column, src: board_columns_closed_path(board), ...`
- i drop URL delle entry (`entry_not_now_path`, `entry_triage_path`, `entry_closure_path`) NON cambiano: sono entry-scoped e la guardia cross-board della Fase 1 protegge il triage

**Step 3:** `columns/_dashboard_column.html.erb` — trova il frame src attuale (`grep -n "dashboard_column\|columns_path" app/views/columns/_dashboard_column.html.erb`) e puntalo a `board_column_path(column.board, column)`.

**Step 4:** Elimina `DashboardController`, `app/controllers/dashboard/`, `app/views/dashboard/`. Poi verifica che nessuna vista li referenzi più:

Run: `grep -rn "dashboard_columns\|dashboard/" app/views app/controllers app/javascript --include="*.erb" --include="*.js" --include="*.rb"`
Expected: nessun risultato (a parte l'helper `dashboard_path`, che ora punta a `boards#default`)

**Step 5: Run** `docker exec prova-app-1 bin/rails test test/controllers/` → PASS. Se esistevano test per `dashboard/columns`, spostali/adattali a `boards/columns`.

**Step 6: Commit**

```bash
git add -A app/controllers/boards app/views/boards app/views/shared/_kanban_board.html.erb app/views/columns/_dashboard_column.html.erb config/routes.rb test/controllers
git rm -r app/controllers/dashboard app/views/dashboard 2>/dev/null; git rm app/controllers/dashboard_controller.rb 2>/dev/null
git commit -m "refactor(boards): Colonne kanban lazy-load nested sotto le board

Rimossi DashboardController e i sub-controller dashboard/columns:
il kanban è lo stesso per ogni board, default inclusa.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Creazione colonne nel contesto board

**Files:**
- Modify: `app/controllers/columns_controller.rb` (`create` e `column_params`)
- Modify: `app/views/columns/_new_column_button.html.erb` (hidden `board_id`)

**Step 1:** Nel form del bottone nuova colonna aggiungi (dentro il `form_with`):

```erb
<%= hidden_field_tag "column[board_id]", board.id %>
```

e passa `board:` al partial dal `_kanban_board` (`render "columns/new_column_button", board: board`).

**Step 2:** In `ColumnsController`:

```ruby
  def column_params
    params.require(:column).permit(:name, :color, :position, :board_id)
  end
```

con guardia in `create`: la board deve essere dell'account — `current_account.boards.find(params[:column][:board_id])` se presente (il fallback `set_default_board` della Fase 1 copre il caso assente, es. da `columns#new` classico).

**Step 3: Test** — aggiungi a `test/controllers/columns_controller_test.rb` (o crea): creare una colonna con `board_id` di `consegne_fizzy` → la colonna appartiene a quella board; senza `board_id` → default board.

**Step 4: Run** i test → PASS. **Step 5: Commit** (`feat(boards): Colonne create nel contesto della board`).

---

### Task 4: Entry#move_to(board) + spostamento dalla UI (TDD)

**Files:**
- Modify: `app/models/concerns/entry/triageable.rb`
- Create: `app/controllers/entries/boards_controller.rb`
- Modify: `config/routes.rb` (dentro `resources :entries ... scope module: :entries`)
- Test: `test/models/entry_test.rb` (estendi), `test/controllers/entries/boards_controller_test.rb`

**Step 1: Test modello** (in `EntryBoardTest`):

```ruby
  test "move_to sposta l'entry su un'altra board azzerando la colonna" do
    entry = Entry.create!(entryable: documenti(:one), user: users(:one),
                          account: accounts(:fizzy))
    column = Column.create!(name: "In corso", board: boards(:dashboard_fizzy))
    entry.triage_into(column)

    entry.move_to(boards(:consegne_fizzy))

    assert_equal boards(:consegne_fizzy), entry.reload.board
    assert_nil entry.column_id
  end

  test "move_to rifiuta una board che non ammette il tipo" do
    entry = Entry.create!(entryable: appunti(:one), user: users(:one),
                          account: accounts(:fizzy))

    assert_raises ArgumentError do
      entry.move_to(boards(:consegne_fizzy))  # ammette solo Documento e Tappa
    end
  end
```

(verifica i label delle fixtures documenti/appunti; l'entryable non deve avere già una Entry)

**Step 2: Run** → FAIL. **Step 3: Implementa** in `Entry::Triageable`:

```ruby
  def move_to(board)
    return if board == self.board
    unless board.allows?(entryable_type)
      raise ArgumentError, "Board #{board.id} does not allow #{entryable_type}"
    end

    transaction do
      clear_states_for_triage
      old_board_name = self.board.name
      update!(board: board, column: nil)
      track_event :board_changed, particulars: { from: old_board_name, to: board.name }
    end
  end
```

**Step 4: Rotta e controller** — in routes, dentro il blocco entries: `resource :board, only: %i[edit update]`.

```ruby
# frozen_string_literal: true

class Entries::BoardsController < ApplicationController
  before_action :set_entry

  def edit
    @boards = current_account.boards.ordered
                             .select { |b| b.allows?(@entry.entryable_type) }
  end

  def update
    board = current_account.boards.find(params[:board_id] || params.dig(:entry, :board_id))
    @entry.move_to(board)
    redirect_to boards_path_for(board), notice: "Card spostata su #{board.name}."
  end

  private

  def set_entry
    @entry = current_account.entries.find(params[:entry_id])
  end

  def boards_path_for(board)
    board.default? ? dashboard_path : board_path(board)
  end
end
```

Vista `edit`: lista di board cliccabili (pattern dialog/menu come `app/views/columns/_menu.html.erb`). Punto di ingresso UI: trova il menu contestuale della card (`grep -rn "entry" app/views/entries/ -l | head` e cerca il partial menu/azioni) e aggiungi la voce "Sposta su board…" → `edit_entry_board_path(entry)`. Se le card non hanno menu contestuale, aggiungi il link nella pagina show dell'entry.

**Step 5: Test controller**: update sposta su board consentita; su board non consentita → errore (assert la response o il non-cambiamento). **Step 6: Run** → PASS. **Step 7: Commit** (`feat(boards): Sposta entry tra board con validazione tipo`).

---

### Task 5: Nuova card multi-tipo da board_tools

**Files:**
- Modify: `app/views/shared/_board_tools.html.erb`
- Modify: `app/controllers/appunti_controller.rb`, `documenti_controller.rb`, `tappe_controller.rb` (solo `create`)
- Create: `app/controllers/concerns/assigns_entry_board.rb`

**Step 1: Partial board-aware** — `_board_tools.html.erb` mostra solo i tipi ammessi e propaga la board:

```erb
<%# locals: (board:) -%>
<div class="board-tools card">
  <% if board.allows?("Documento") %>
    <%= link_to new_documento_path(board_id: board.id), class: "btn btn--link", data: { turbo_frame: "_top" } do %>
      <%= icon_tag "document" %>
      <span>Documento</span>
      <kbd class="hide-on-touch">D</kbd>
    <% end %>
  <% end %>

  <% if board.allows?("Appunto") %>
    <%= link_to new_appunto_path(board_id: board.id), class: "btn btn--link", data: { turbo_frame: "_top" } do %>
      <%= icon_tag "note" %>
      <span>Appunto</span>
      <kbd class="hide-on-touch">A</kbd>
    <% end %>
  <% end %>

  <% if board.allows?("Tappa") %>
    <%= link_to new_tappa_path(board_id: board.id), class: "btn btn--link", data: { turbo_frame: "_top" } do %>
      <%= icon_tag "map-pin" %>
      <span>Tappa</span>
    <% end %>
  <% end %>
</div>
```

Note: (1) il markup attuale ha un bug preesistente `<kbd ...</span>` — sistemalo in `</kbd>` già che lo tocchi; (2) verifica che `new_tappa_path` esista e quale icona tappa è registrata (`grep -rn "map-pin\|tappa" app/helpers/icon*` o dove vive `icon_tag`) — se manca l'icona usa la skill icon-agent; (3) il partial è renderizzato anche dal triage del kanban (`_kanban_board` riga 81): passa `board: board` anche lì; (4) altri caller: `grep -rn "board_tools" app/views` e passa la board (nelle pagine non-board usa `current_account.default_board`).

**Step 2: Concern** — `app/controllers/concerns/assigns_entry_board.rb`:

```ruby
# frozen_string_literal: true

# Dopo la creazione di un entryable, sposta la sua entry sulla board
# indicata da params[:board_id] (se presente e diversa dalla default).
module AssignsEntryBoard
  extend ActiveSupport::Concern

  private

  def assign_entry_board(entryable)
    return if params[:board_id].blank?
    return if entryable.nil? || entryable.entry.nil?

    board = current_account.boards.find_by(id: params[:board_id])
    return if board.nil? || board == entryable.entry.board

    entryable.entry.move_to(board)
  rescue ArgumentError
    # board che non ammette il tipo: la card resta sulla default
  end
end
```

**Step 3: Aggancialo nei tre `create`** (include il concern nel controller):
- `AppuntiController#create` (format.html): dopo `creator.create` → `assign_entry_board(creator.appunto)`. Il `new` deve propagare `board_id` nel form: aggiungi `hidden_field_tag :board_id, params[:board_id]` nella vista new/form dell'appunto (trova il form: `grep -rn "form" app/views/appunti/new*`). Limite noto: gli appunti drafted non hanno entry finché non pubblicati — in quel caso `assign_entry_board` è un no-op e la card nascerà sulla default alla pubblicazione (accettato per la Fase 2).
- `DocumentiController#create`: dopo `@documento.save` → `assign_entry_board(@documento)` + hidden `board_id` nel form new.
- `TappeController#create`: dopo `@tappa.save` (e nel ramo `existing`? no — la tappa esistente ha già la sua board) → `assign_entry_board(@tappa)`. Le tappe future non hanno entry (creata al raggiungimento della data): no-op accettato, la board si sceglierà spostando la card.

**Step 4: Test** — controller test per documenti (il flusso più lineare): `post documenti_path(..., board_id: boards(:consegne_fizzy).id, params: {...})` → `documento.entry.board == consegne_fizzy`.

**Step 5: Run** i test → PASS. **Step 6: Commit** (`feat(boards): Nuova card multi-tipo dal contesto board`).

---

### Task 6: Broadcast per board

**Files:**
- Modify: `app/models/concerns/entry/broadcastable.rb`
- Modify: `app/views/boards/show.html.erb`

**Step 1:** Aggiungi il canale board:

```ruby
    # Broadcast refresh to the board channel (kanban of that board)
    broadcasts_refreshes_to ->(entry) { entry.board }
```

**Step 2:** In `boards/show.html.erb`, in cima: `<%= turbo_stream_from @board %>`.

Nota memoria progetto: la subscription NON va dentro elementi `turbo_permanent`, e `broadcasts_refreshes_to` è async via Sidekiq — per vederla in dev serve il worker attivo.

Il canale `[user, "entries"]` resta (viste trasversali e layout). Attenzione: ogni update di entry ora fa 3 broadcast — se in smoke test i refresh raddoppiati causano flicker, valuta di tenere solo `[user, "entries"]` + board e togliere il canale singolo? NO: il canale singolo serve alle show page. Lascia tutto e osserva.

**Step 3: Smoke test** (2 browser): sposta una card sulla board Consegne in una finestra → l'altra finestra sulla stessa board si aggiorna; il dashboard nell'altra finestra NON mostra più la card.

**Step 4: Commit** (`feat(boards): Broadcast refresh sul canale della board`).

---

### Task 7: boards#index + navigazione

**Files:**
- Create: `app/views/boards/index.html.erb`
- Modify: layout/navbar (da individuare)

**Step 1:** Trova dove sta il link al dashboard nella navigazione:

Run: `grep -rn "dashboard_path\|account_root" app/views/layouts app/views/shared --include="*.erb" | head`

**Step 2:** `index.html.erb`: lista card-style delle board (nome, badge dei tipi, conteggio entry attive `board.entries.active.count`, link). La default per prima, poi `ordered`. Bottone "Nuova board" → `new_board_path`. Segui i pattern lista di Fizzy (`app/views/columns/index.html.erb` come riferimento di stile).

**Step 3:** Aggiungi il link "Boards" (`boards_path`) accanto al link dashboard nella navbar individuata.

**Step 4: Test**: `get boards_path(...)` → success, contiene i nomi delle board fixtures. **Step 5: Commit** (`feat(boards): Indice board e voce di navigazione`).

---

### Task 8: Suite completa + annotate + smoke finale

**Step 1:** `docker exec prova-app-1 bin/rails test` → verde (occhio ai test che referenziavano `dashboard#index` o `dashboard_columns_*`).
**Step 2:** `docker exec prova-app-1 bin/rails test test/system/` (se i system test girano in locale) o smoke manuale:
- `/dashboard`: identico a prima (board default)
- crea board "Consegne" con soli Documento+Tappa → board_tools mostra solo quei 2 bottoni
- nuovo documento dalla board → la card nasce lì, in "Da gestire"
- drag&drop nelle colonne della board; colonna nuova; sposta la card sul dashboard dal menu
- elimina la board → le card tornano al dashboard in triage
**Step 3:** `docker exec prova-app-1 bundle exec annotaterb models` e committa eventuali annotation.
**Step 4:** Commit finale se restano file.

---

## Fuori scope (fasi successive)

- **Fase 3**: tabella `accesses`, `all_access` reale, form membri, gate `accessible_to?` — in Fase 2 ogni board è visibile a tutto l'account e `boards#index` mostra tutte le board
- **Fase 4**: `board_publications`, `Public::BoardsController`, vista read-only
- Ordinamento board per accesso recente (`accesses.accessed_at`): arriva con la Fase 3; per ora `ordered` per nome
