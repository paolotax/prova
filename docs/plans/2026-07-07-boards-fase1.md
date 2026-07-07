# Boards Fase 1 (Fondamenta) — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Introdurre il modello `Board` e rendere colonne ed entry board-scoped, con il dashboard che diventa la board di default — comportamento utente identico a oggi.

**Architecture:** Opzione C del design (`docs/plans/2026-07-07-boards-design.md`): `entry.board_id` e `column.board_id` NOT NULL, una board default per account creata via backfill, assegnazione automatica alla default per tutti i flussi di creazione esistenti. Nessuna UI nuova in questa fase.

**Tech Stack:** Rails 8.1, PostgreSQL (structure.sql), Minitest + fixtures, Docker (`prova-app-1`).

**Regole di contesto:**
- Tutti i comandi Rails girano nel container: `docker exec prova-app-1 bin/rails ...`
- Convenzioni migration del progetto: UUID, `account_id`, **niente foreign key** (vedi skill migration-agent)
- Si lavora **direttamente sul branch corrente `main`** (preferenza utente: niente worktree)
- Commit solo dei file del task, mai `git add -A`
- Le fasi 2–4 (CRUD board, sharing, link pubblico) sono FUORI scope: non anticiparle (YAGNI)

---

### Task 0: Pre-flight — working tree pulito

Il working tree contiene lavoro MIUR non committato che tocca `db/structure.sql`. La migration di questo piano modifica lo stesso file: se non si parte puliti, il commit della migration trascinerebbe dentro il diff MIUR.

**Step 1: Verifica lo stato**

Run: `git status --short`

**Step 2: Se compaiono file MIUR** (`db/migrate/*miur*`, `app/models/miur*`, `db/structure.sql`, `test/**/miur*`): **STOP — chiedi all'utente** di committare (o stashare) il lavoro MIUR prima di procedere. Non proseguire con `structure.sql` sporco.

**Step 3: Verifica container**

Run: `docker ps --filter name=prova-app-1 --format '{{.Status}}'`
Expected: `Up ...` (se assente: `bin/dev` in un altro terminale; se flappa, controlla prova-redis-1)

---

### Task 1: Migration — tabella boards + board_id su columns/entries + backfill

**Files:**
- Create: `db/migrate/<timestamp>_create_boards.rb` (genera il timestamp con il comando sotto)
- Modify (auto): `db/structure.sql`

**Step 1: Genera la migration**

Run: `docker exec prova-app-1 bin/rails generate migration CreateBoards`

**Step 2: Scrivi la migration** (sostituisci il contenuto del file generato):

```ruby
# frozen_string_literal: true

class CreateBoards < ActiveRecord::Migration[8.1]
  def up
    create_table :boards, id: :uuid do |t|
      t.uuid :account_id, null: false
      t.bigint :creator_id
      t.string :name, null: false
      t.string :entry_types, array: true, null: false, default: %w[Appunto Documento Tappa]
      t.boolean :all_access, null: false, default: false
      t.boolean :default, null: false, default: false
      t.timestamps
    end
    add_index :boards, :account_id
    add_index :boards, :account_id, unique: true, where: '"default"',
              name: "index_boards_on_account_id_default"

    add_column :columns, :board_id, :uuid
    add_column :entries, :board_id, :uuid

    # Backfill: una board default per account, creator = membro con ruolo più alto
    execute <<~SQL
      INSERT INTO boards (id, account_id, creator_id, name, all_access, "default", created_at, updated_at)
      SELECT gen_random_uuid(), a.id, m.user_id, 'Dashboard', TRUE, TRUE, NOW(), NOW()
      FROM accounts a
      LEFT JOIN LATERAL (
        SELECT user_id FROM memberships
        WHERE memberships.account_id = a.id
        ORDER BY role DESC
        LIMIT 1
      ) m ON TRUE
    SQL

    execute <<~SQL
      UPDATE columns SET board_id = b.id
      FROM boards b
      WHERE b.account_id = columns.account_id AND b."default"
    SQL

    execute <<~SQL
      UPDATE entries SET board_id = b.id
      FROM boards b
      WHERE b.account_id = entries.account_id AND b."default"
    SQL

    change_column_null :columns, :board_id, false
    change_column_null :entries, :board_id, false

    add_index :columns, [ :board_id, :position ]
    add_index :columns, [ :board_id, :name ], unique: true
    remove_index :columns, name: "index_columns_on_account_id_and_name"
    add_index :entries, :board_id
  end

  def down
    add_index :columns, [ :account_id, :name ], unique: true,
              name: "index_columns_on_account_id_and_name"
    remove_column :columns, :board_id
    remove_column :entries, :board_id
    drop_table :boards
  end
end
```

Nota: niente foreign key (convenzione progetto). L'unicità del nome colonna passa da `[account_id, name]` a `[board_id, name]` (prepara le board multiple della Fase 2).

**Step 3: Esegui la migration**

Run: `docker exec prova-app-1 bin/rails db:migrate`
Expected: nessun errore, `structure.sql` rigenerato

**Step 4: Verifica il backfill**

Run:
```bash
docker exec prova-app-1 bin/rails runner '
  puts "boards: #{ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM boards")}"
  puts "accounts: #{Account.count}"
  puts "columns senza board: #{ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM columns WHERE board_id IS NULL")}"
  puts "entries senza board: #{ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM entries WHERE board_id IS NULL")}"
'
```
Expected: `boards` = `accounts`, entrambi i "senza board" = 0

**Step 5: Verifica la rollbackability**

Run: `docker exec prova-app-1 bin/rails db:rollback && docker exec prova-app-1 bin/rails db:migrate`
Expected: entrambe senza errori (il backfill rigira: le board vengono ricreate)

**Step 6: Commit**

```bash
git add db/migrate/*_create_boards.rb db/structure.sql
git commit -m "feat(boards): Crea tabella boards e board_id su columns/entries

Ogni account riceve una board default 'Dashboard' via backfill;
colonne ed entry esistenti vengono agganciate ad essa. Prepara le
board multiple: l'unicità del nome colonna passa da account a board.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Fixtures boards

**Files:**
- Create: `test/fixtures/boards.yml`

Le fixtures esistenti: account `fizzy` (owner: user `one`/alice) e `acme`. Non esistono fixtures per columns/entries.

**Step 1: Scrivi le fixtures**

```yaml
dashboard_fizzy:
  account: fizzy
  creator: one
  name: Dashboard
  entry_types: ["Appunto", "Documento", "Tappa"]
  all_access: true
  default: true

dashboard_acme:
  account: acme
  name: Dashboard
  entry_types: ["Appunto", "Documento", "Tappa"]
  all_access: true
  default: true

consegne_fizzy:
  account: fizzy
  creator: one
  name: Consegne
  entry_types: ["Documento", "Tappa"]
  all_access: false
  default: false
```

**Step 2: Verifica che le fixtures carichino** (l'array PG da YAML deve serializzare correttamente)

Run: `docker exec prova-app-1 bin/rails test test/models/account_test.rb`
Expected: verde (o comunque nessun errore di caricamento fixtures). Se l'array non serializza, usare la forma stringa PG: `entry_types: "{Appunto,Documento,Tappa}"`

**Step 3: Commit**

```bash
git add test/fixtures/boards.yml
git commit -m "test(boards): Fixtures per board default e board secondaria

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Modello Board (TDD)

**Files:**
- Create: `app/models/board.rb`
- Create: `test/models/board_test.rb`

**Step 1: Scrivi i test (falliranno)**

```ruby
# frozen_string_literal: true

require "test_helper"

class BoardTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
  end

  teardown do
    Current.reset
  end

  test "valida che entry_types contenga solo tipi noti" do
    board = Board.new(name: "Test", entry_types: %w[Documento Alieno])
    assert_not board.valid?
    assert board.errors[:entry_types].any?
  end

  test "entry_types non può essere vuoto" do
    board = Board.new(name: "Test", entry_types: [])
    assert_not board.valid?
  end

  test "allows? risponde in base a entry_types" do
    board = boards(:consegne_fizzy)
    assert board.allows?("Documento")
    assert board.allows?(:Tappa)
    assert_not board.allows?("Appunto")
  end

  test "una sola board default per account" do
    assert_raises ActiveRecord::RecordNotUnique do
      Board.create!(name: "Doppione", default: true, account: accounts(:fizzy))
    end
  end

  test "la board default non si può eliminare" do
    board = boards(:dashboard_fizzy)
    assert_not board.destroy
    assert board.errors[:base].any?
  end

  test "destroy sposta le entry alla board default e le rimette in triage" do
    board = boards(:consegne_fizzy)
    appunto = appunti(:one)
    entry = Entry.create!(entryable: appunto, user: users(:one),
                          account: accounts(:fizzy), board: board)

    assert board.destroy
    entry.reload
    assert_equal boards(:dashboard_fizzy), entry.board
    assert_nil entry.column_id
  end

  test "creator di default è Current.user" do
    board = Board.create!(name: "Nuova")
    assert_equal users(:one), board.creator
  end
end
```

Nota: verifica il label della fixture appunti con `grep -vE "^#|^$" test/fixtures/appunti.yml | head` — se non è `one`, adegua il test. Se la fixture appunto crea già una Entry via callback o ha vincoli extra, usa un Documento o crea l'appunto nel test.

**Step 2: Esegui — devono fallire**

Run: `docker exec prova-app-1 bin/rails test test/models/board_test.rb`
Expected: FAIL/ERROR (`uninitialized constant Board`)

**Step 3: Implementa il modello**

```ruby
# frozen_string_literal: true

class Board < ApplicationRecord
  include AccountScoped

  belongs_to :creator, class_name: "User", optional: true, default: -> { Current.user }

  has_many :columns, dependent: :destroy
  has_many :entries

  validates :name, presence: true
  validates :entry_types, presence: true
  validate :entry_types_must_be_known

  before_destroy :prevent_default_destruction
  before_destroy :move_entries_to_default_board

  scope :ordered, -> { order(:name) }

  def allows?(entryable_type)
    entry_types.include?(entryable_type.to_s)
  end

  private

  def entry_types_must_be_known
    unknown = Array(entry_types) - Entry.entryable_types
    errors.add(:entry_types, "contiene tipi non validi: #{unknown.join(', ')}") if unknown.any?
  end

  def prevent_default_destruction
    return unless default?

    errors.add(:base, "La board di default non può essere eliminata")
    throw :abort
  end

  def move_entries_to_default_board
    entries.update_all(board_id: account.default_board.id, column_id: nil,
                       updated_at: Time.current)
  end
end
```

Nota: `Entry.entryable_types` è il class method generato da `delegated_type` (Rails 8). Verificalo: `docker exec prova-app-1 bin/rails runner 'puts Entry.entryable_types.inspect'` → `["Appunto", "Documento", "Tappa"]`. Se non esistesse, definisci una costante in Entry e usala.

`account.default_board` arriva nel Task 4: il test di destroy resterà rosso fino ad allora — è atteso.

**Step 4: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/board_test.rb`
Expected: tutto verde TRANNE "destroy sposta le entry..." (manca `Account#default_board`, Task 4)

**Step 5: Commit**

```bash
git add app/models/board.rb test/models/board_test.rb
git commit -m "feat(boards): Modello Board con tipi entry configurabili

entry_types è un array PG validato sui delegated type di Entry.
La board default non è cancellabile; la destroy di una board
sposta le entry alla default rimettendole in triage.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Account#default_board (TDD)

**Files:**
- Modify: `app/models/account.rb` (sezione "Triage system", riga ~44)
- Create: `test/models/account_board_test.rb`

**Step 1: Scrivi i test**

```ruby
# frozen_string_literal: true

require "test_helper"

class AccountBoardTest < ActiveSupport::TestCase
  test "default_board trova la board default esistente" do
    assert_equal boards(:dashboard_fizzy), accounts(:fizzy).default_board
  end

  test "default_board crea la board se manca" do
    account = Account.create!(name: "Nuovo Team")
    board = account.default_board

    assert board.persisted?
    assert board.default?
    assert board.all_access?
    assert_equal "Dashboard", board.name
    assert_equal Entry.entryable_types.sort, board.entry_types.sort
  end
end
```

**Step 2: Esegui — devono fallire**

Run: `docker exec prova-app-1 bin/rails test test/models/account_board_test.rb`
Expected: FAIL (`undefined method 'default_board'`)

**Step 3: Implementa** — in `app/models/account.rb`, nella sezione Triage system aggiungi l'associazione e i metodi:

```ruby
  # Triage system
  has_many :boards, dependent: :destroy
  has_many :columns, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :events, dependent: :destroy
```

e più sotto, tra i metodi pubblici:

```ruby
  def default_board
    boards.find_by(default: true) || create_default_board!
  end

  private

  def create_default_board!
    boards.create!(
      name: "Dashboard",
      default: true,
      all_access: true,
      creator: memberships.order(role: :desc).first&.user
    )
  end
```

Attenzione: se `account.rb` ha già una sezione `private`, accoda lì `create_default_board!` invece di aprirne un'altra.

**Step 4: Esegui i test** (inclusi quelli di Board, ora tutti verdi)

Run: `docker exec prova-app-1 bin/rails test test/models/account_board_test.rb test/models/board_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/account.rb test/models/account_board_test.rb
git commit -m "feat(boards): Account#default_board con creazione lazy

Gli account esistenti hanno la board dal backfill; i nuovi la
ricevono al primo accesso al dashboard senza hook di creazione.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Column board-scoped (TDD)

**Files:**
- Modify: `app/models/column.rb`
- Test: `test/models/column_test.rb` (se esiste, estendi; altrimenti crea)

**Step 1: Scrivi i test** (aggiungili al file esistente se c'è — controlla prima con `ls test/models/column_test.rb`)

```ruby
# frozen_string_literal: true

require "test_helper"

class ColumnTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
  end

  teardown do
    Current.reset
  end

  test "una colonna creata senza board finisce sulla board default" do
    column = Column.create!(name: "Test board default")
    assert_equal boards(:dashboard_fizzy), column.board
  end

  test "il nome è unico per board, non per account" do
    Column.create!(name: "Doppia", board: boards(:dashboard_fizzy))
    assert_nothing_raised do
      Column.create!(name: "Doppia", board: boards(:consegne_fizzy))
    end
  end

  test "position e navigazione left/right sono scoped sulla board" do
    a = Column.create!(name: "A", board: boards(:consegne_fizzy))
    b = Column.create!(name: "B", board: boards(:consegne_fizzy))
    Column.create!(name: "Altrove", board: boards(:dashboard_fizzy))

    assert_equal 0, a.position
    assert_equal 1, b.position
    assert a.leftmost?
    assert_equal b, a.right_column
    assert_equal a, b.left_column
    assert b.rightmost?
  end

  test "create_defaults_for crea le colonne di default sulla board" do
    board = boards(:consegne_fizzy)
    Column.create_defaults_for(board)
    assert_equal [ "Nel baule", "La prossima" ], board.columns.ordered.pluck(:name)
  end
end
```

**Step 2: Esegui — devono fallire**

Run: `docker exec prova-app-1 bin/rails test test/models/column_test.rb`
Expected: FAIL (`Column` non ha `board`)

**Step 3: Modifica `app/models/column.rb`** — le modifiche puntuali:

```ruby
class Column < ApplicationRecord
  include AccountScoped
  include Colored

  belongs_to :board, touch: true

  has_many :entries, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :board_id }

  scope :ordered, -> { order(:position) }

  before_validation :set_default_board, on: :create
  before_create :set_position_at_end
```

`create_defaults_for` diventa per-board (era per-account e non è chiamato da nessuna parte nel codice — verifica con `grep -rn "create_defaults_for" app lib db config`):

```ruby
  def self.create_defaults_for(board)
    DEFAULT_COLUMNS.each_with_index do |attrs, index|
      board.columns.find_or_create_by!(name: attrs[:name]) do |col|
        col.color = attrs[:color]
        col.position = index
        col.account = board.account
      end
    end
  end
```

I metodi di navigazione passano da `account.columns` a `board.columns`:

```ruby
  def left_column
    board.columns.where("position < ?", position).ordered.last
  end

  def right_column
    board.columns.where("position > ?", position).ordered.first
  end

  def adjacent_columns
    board.columns.where(id: [ left_column&.id, right_column&.id ].compact)
  end
```

E i private:

```ruby
  private

  def set_default_board
    self.board ||= account&.default_board
  end

  def set_position_at_end
    max_position = board.columns.maximum(:position) || -1
    self.position = max_position + 1
  end
```

Nota ordine callback: `AccountScoped` registra `set_account_from_current` alla `include` (prima riga della classe), quindi gira PRIMA di `set_default_board` — l'account è già valorizzato. Non cambiare l'ordine delle include.

**Step 4: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/column_test.rb`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/column.rb test/models/column_test.rb
git commit -m "feat(boards): Colonne board-scoped con fallback sulla default

belongs_to :board con touch; unicità nome e navigazione
left/right ora per board. I flussi esistenti che creano colonne
senza board continuano a funzionare (fallback su default_board).

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Entry board-scoped + guardia triage (TDD)

**Files:**
- Modify: `app/models/entry.rb`
- Modify: `app/models/concerns/entry/triageable.rb`
- Test: `test/models/entry_test.rb` (estendi se esiste, altrimenti crea)

**Step 1: Scrivi i test**

```ruby
# frozen_string_literal: true

require "test_helper"

class EntryBoardTest < ActiveSupport::TestCase
  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
  end

  teardown do
    Current.reset
  end

  test "una entry creata senza board finisce sulla board default" do
    entry = Entry.create!(entryable: appunti(:one), user: users(:one),
                          account: accounts(:fizzy))
    assert_equal boards(:dashboard_fizzy), entry.board
  end

  test "triage_into rifiuta colonne di un'altra board" do
    entry = Entry.create!(entryable: appunti(:one), user: users(:one),
                          account: accounts(:fizzy))
    other_column = Column.create!(name: "Altrove", board: boards(:consegne_fizzy))

    assert_raises ArgumentError do
      entry.triage_into(other_column)
    end
    assert_nil entry.reload.column_id
  end

  test "triage_into accetta colonne della stessa board" do
    entry = Entry.create!(entryable: appunti(:one), user: users(:one),
                          account: accounts(:fizzy))
    column = Column.create!(name: "Mia colonna", board: boards(:dashboard_fizzy))

    entry.triage_into(column)
    assert_equal column, entry.reload.column
  end
end
```

Stessa avvertenza del Task 3 sul label della fixture appunti; usa entryable diversi nei tre test se l'indice UNIQUE `(entryable_type, entryable_id)` collide (ogni test è in transazione separata, quindi lo stesso appunto va bene).

**Step 2: Esegui — devono fallire**

Run: `docker exec prova-app-1 bin/rails test test/models/entry_test.rb`
Expected: FAIL

**Step 3: Modifica `app/models/entry.rb`** — dopo `belongs_to :column, optional: true`:

```ruby
  belongs_to :board
```

e tra i callback (dopo le associazioni):

```ruby
  before_validation :set_default_board, on: :create
```

con il private method in fondo alla classe:

```ruby
  private

  def set_default_board
    self.board ||= account&.default_board
  end
```

**Step 4: Modifica `app/models/concerns/entry/triageable.rb`** — guardia cross-board su entrambi i metodi che assegnano una colonna:

```ruby
  def triage_into(column)
    ensure_column_on_same_board!(column)

    transaction do
      clear_states_for_triage
      update!(column: column)
      track_event :triaged, particulars: { column: column.name }
    end
  end
```

```ruby
  def move_to_column(column)
    return if self.column == column

    ensure_column_on_same_board!(column)

    transaction do
      # ... corpo invariato
    end
  end
```

e nel `private`:

```ruby
  def ensure_column_on_same_board!(column)
    return if column.nil? || column.board_id == board_id

    raise ArgumentError, "Column #{column.id} belongs to a different board"
  end
```

**Step 5: Esegui i test**

Run: `docker exec prova-app-1 bin/rails test test/models/entry_test.rb`
Expected: PASS

**Step 6: Commit**

```bash
git add app/models/entry.rb app/models/concerns/entry/triageable.rb test/models/entry_test.rb
git commit -m "feat(boards): Entry appartiene a una board, triage validato

Le entry nascono sulla board default dell'account (opzione C del
design: una entità = una entry = una board). triage_into e
move_to_column rifiutano colonne di board diverse, come
Card::Triageable in Fizzy.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: Dashboard legge dalla board default

**Files:**
- Modify: `app/controllers/dashboard_controller.rb:10,24`

**Step 1: Modifica il controller** — in `index`:

```ruby
  def index
    @board = current_account.default_board
    base_scope = @board.entries.published.then { |s| filter_own_tappe(s) }
```

e più sotto:

```ruby
      @columns = @board.columns.ordered
```

Non toccare `Dashboard::ColumnsController` né gli altri sub-controller: leggono da `current_account.columns`/`current_account.entries`, che in Fase 1 coincidono con la board default. Verranno nested sotto le board in Fase 2.

**Step 2: Esegui i test dei controller**

Run: `docker exec prova-app-1 bin/rails test test/controllers/`
Expected: PASS (nessuna modifica di comportamento)

**Step 3: Commit**

```bash
git add app/controllers/dashboard_controller.rb
git commit -m "feat(boards): Il dashboard legge dalla board default

Comportamento identico: in Fase 1 tutte le entry e colonne
dell'account vivono sulla board default.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Suite completa + annotate + smoke test

**Step 1: Suite completa**

Run: `docker exec prova-app-1 bin/rails test`
Expected: verde. Failure probabili e come leggerli:
- test che creano Column/Entry senza `Current.account` né account esplicito → il fallback `set_default_board` torna nil e `belongs_to :board` fallisce: sistemare il TEST impostando `Current.account`, non allentare la validazione
- test che contano query o fixtures che assumono l'unicità nome-colonna per account

**Step 2: Annotate**

Run: `docker exec prova-app-1 bundle exec annotaterb models`
Expected: aggiornate le annotation di `board.rb`, `column.rb`, `entry.rb` (e nessun altro file — se annotaterb tocca altro, escludilo dal commit)

**Step 3: Smoke test manuale** (app su localhost via `bin/dev`):
- apri il dashboard: colonne e card come prima
- trascina una card in una colonna e in "Chiusi": funziona e il morph aggiorna
- crea una colonna nuova dal bottone "+": appare in fondo a destra
- crea un appunto: compare in "Da gestire"

**Step 4: Commit finale**

```bash
git add app/models/board.rb app/models/column.rb app/models/entry.rb
git commit -m "chore(annotate): Aggiorna annotation per board_id

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Fuori scope (fasi successive del design)

- **Fase 2**: CRUD board, `boards#index`, nuova card multi-tipo, `Entry#move_to(board)`, rotte `resources :boards`, broadcast per board
- **Fase 3**: tabella `accesses`, `all_access`, form membri
- **Fase 4**: `board_publications`, `Public::BoardsController`, vista read-only

Non creare tabelle o colonne per queste fasi adesso (il design le elencava in un'unica migration; si è scelto di crearle nella fase che le usa).
