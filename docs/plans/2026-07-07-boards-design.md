# Boards e Columns — Design

**Data:** 2026-07-07
**Stato:** validato, da implementare
**Riferimento:** sistema boards/columns/cards di Fizzy (`/home/paolotax/rails_2023/fizzy`)

## Obiettivo

Introdurre le **Board** in Prova sul modello di Fizzy: kanban multipli per account, ognuno con le proprie colonne, condivisibili con membri selezionati o via link pubblico. Ogni board dichiara quali **tipi di entry** ammette (Appunto, Documento, Tappa) e il bottone "nuova card" crea direttamente quei tipi.

## Decisioni chiave

| Decisione | Scelta | Alternative scartate |
|---|---|---|
| Natura della board | **Fizzy puro (opzione C)**: `entry.board_id`, un'entità = una entry = una board. L'indice UNIQUE su `(entryable_type, entryable_id)` resta | A) più entry per entità (rompe l'1:1, refactoring invasivo di Entryable e stati); B) entry unica + tabella `placements` per-board (indirection permanente; C è un sottoinsieme di B, migrabile in futuro se servirà multi-board) |
| Tipo entry | **Multi-tipo configurabile**: la board dichiara un set di tipi ammessi, validato sia in creazione che in `move_to` | Solo default di creazione; vincolo rigido mono-tipo |
| Dashboard attuale | **Diventa la board default** dell'account (una per account, tutti i tipi, non cancellabile). `/dashboard` la mostra | Vista aggregata separata (colonne ambigue tra dashboard e board) |
| Sharing | **Completo fin dalla v1**: accesses per utente + `all_access` + link pubblico read-only con token segreto | Solo membri account; solo accesses |
| Tappe | **Regola attuale ovunque** (`ScopesOwnTappe`): ogni membro vede solo le proprie tappe anche sulle board condivise. Il link pubblico non mostra mai tappe | Filtro solo su board default; tappe team-wide |

## Schema dati

```
boards
  id uuid PK
  account_id uuid (indice)
  creator_id bigint
  name string not null
  entry_types string[] not null, default ["Appunto","Documento","Tappa"]
  all_access boolean not null default false
  default boolean not null default false
  created_at / updated_at
  -- indice parziale UNIQUE su account_id WHERE default

accesses
  id uuid PK
  account_id uuid
  board_id uuid + user_id bigint (UNIQUE insieme)
  accessed_at datetime            -- per ordinare le board per accesso recente

board_publications
  id uuid PK
  board_id uuid (UNIQUE)
  key string (UNIQUE)             -- has_secure_token

columns  → + board_id uuid not null (indice [board_id, position])
entries  → + board_id uuid not null (indice)
```

Note:
- `entry_types` è un array Postgres (più semplice di una join table, non serve interrogarlo dal lato opposto).
- Convenzioni progetto: UUID, `account_id` ovunque, niente foreign key.
- Le colonne migrano da account-scoped a board-scoped; `position` e la logica swap left/right restano identiche.

## Modelli

**`Board`** (nuovo):
- `belongs_to :account`, `belongs_to :creator` (default `Current.user`)
- `has_many :columns, dependent: :destroy`; `has_many :entries` — alla destroy della board le entry tornano alla board default (`before_destroy :move_entries_to_default_board`), mai distrutte (più sicuro di Fizzy)
- Concerns: `Board::Accessible`, `Board::Publishable`
- `entry_types` validato come sottoinsieme dei tipi entryable; `allows?(type)`
- La board default: sempre `all_access`, non cancellabile, tipi non restringibili

**`Column`**: `belongs_to :board, touch: true` al posto del legame diretto all'account. `create_defaults_for` diventa per-board. Swap left/right invariato.

**`Entry`**: `belongs_to :board`. `Entry::Triageable#triage_into` valida che la colonna appartenga alla stessa board (come `Card::Triageable` di Fizzy). Nuovo `move_to(board)`: valida `board.allows?(entryable_type)`, azzera `column_id`, pulisce NotNow. Scope `active`/`awaiting_triage`/`triaged` invariati, composti con `board.entries`.

**`Entryable`** (concern): `create_entry_record` assegna la board — quella esplicita dal contesto di creazione o la default dell'account. Le deleghe (`golden?`, `closed?`, …) non si toccano.

**Stati globali**: Goldness/Closure/NotNow ignorano le board. Rimandati/Chiusi restano pseudo-colonne di ogni board.

**Broadcast**: `Entry::Broadcastable` aggiunge `broadcasts_refreshes_to -> { entry.board }`; il canale `[user, "entries"]` resta per le viste trasversali.

## Controller, rotte, UI

```ruby
resources :boards do
  scope module: :boards do
    resources :columns, only: :show          # lazy-load colonna kanban
    namespace :columns do
      resource :postponed, :closed, only: :show
    end
    resource :publication, only: [:create, :destroy]
  end
end
get "dashboard", to: "boards#default"        # board default dell'account
```

- `BoardsController#show` generalizza l'attuale `DashboardController#index`: `base_scope = @board.entries.published` + `filter_own_tappe`. I sotto-controller `dashboard/columns/*` migrano sotto `boards/columns/*`.
- `ColumnsController` (CRUD + left/right position) resta, con la board come parent.
- `shared/_kanban_board` riceve `board:` invece di leggere `current_account.columns`. Drag&drop, colonne collassabili, turbo frame: invariati, cambiano solo i path.
- **Nuova card multi-tipo**: il bottone "+" mostra i tipi di `board.entry_types` (se uno solo, crea diretto) e porta ai form esistenti con `board_id` nel contesto.
- **`boards#index`**: board accessibili all'utente, ordinate per `accesses.accessed_at`. Entra nel menu principale.
- **Spostare entry tra board**: `Entries::BoardsController#update` → `entry.move_to(board)`, scelta limitata alle board che ammettono quel tipo.

## Sharing

**Interno** (`Board::Accessible`, ricalcato da Fizzy):
- `all_access: true` → Access per ogni membro attivo, hook anche su creazione Membership futura
- `all_access: false` → selettiva: form di edit con scelta membri (`accesses.revise(granted:, revoked:)`)
- Il creator riceve sempre l'accesso; `accessible_to?(user)` è il gate nei controller; `boards#index` mostra solo `current_user.boards`
- Solo admin/owner dell'account (o il creator) modificano accessi e pubblicazione

**Pubblico** (`Board::Publishable` + `Board::Publication`):
- `publish`/`unpublish`; token nuovo a ogni ripubblicazione
- `get "public/boards/:key"` → `Public::BoardsController#show`, fuori dal prefisso account, senza login
- Vista read-only: kanban senza drag&drop né azioni, solo entry `active` e `published`, niente Rimandati/Chiusi, **niente tappe**
- ⚠️ I documenti espongono importi e clienti: la card preview pubblica va ridotta (titolo e scuola/cliente sì; importi da decidere in implementazione)

## Migrazione dati

Una migration + backfill (dataset piccolo):
1. Crea `boards`, `accesses`, `board_publications`; `board_id` nullable su `columns` ed `entries`
2. Backfill: per ogni account una board default ("Dashboard", `default: true`, `all_access: true`, tutti i tipi, creator = owner); colonne ed entry esistenti ricevono quel `board_id`
3. `board_id` → NOT NULL; Access per tutti i membri attivi
4. `down` reversibile: drop tabelle + rimozione colonne

## Test

- `board_test.rb` — validazione `entry_types`, `allows?`, unica default per account, destroy sposta le entry alla default
- `entry_test.rb` — `move_to` valida tipo e azzera colonna; `triage_into` rifiuta colonne di altre board
- `board/accessible_test.rb` — all_access crea accessi, revise concede/revoca, nuovo membro entra nelle all_access
- Controller — accesso negato senza Access; `Public::BoardsController` con key valida/invalida/spubblicata; assenza tappe nel pubblico
- Sistema — drag&drop su board non-default

## Fasi di implementazione

Quattro fasi committabili separatamente, app sempre funzionante:

1. **Fondamenta** — Board + migrazione + colonne board-scoped, dashboard = board default. Nessuna UI nuova: comportamento identico a oggi
2. **Board multiple** — CRUD board, indice, nuova card multi-tipo, `move_to`
3. **Sharing interno** — accesses, all_access, form membri
4. **Link pubblico** — publication, `Public::*`, vista read-only
