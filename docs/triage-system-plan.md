# Piano: Sistema Triage Unificato con Delegated Types

## Obiettivo
Creare un sistema unificato per pianificare consegne/ritiri di:
- **Appunti** (ordini/note clienti)
- **Documenti** (fatture/DDT)
- **Tappe** (visite scuola per un giro specifico)

Con: triage kanban, eventi, stati condivisi, fasi consegna/ritiro.

---

## Design: Delegated Types Pattern

### Il Pattern
```
Entry (Recording)
├── delegated_type :entryable
│   ├── Appunto
│   ├── Documento
│   └── Tappa
├── belongs_to :column (fase: consegna, ritiro, ecc.)
├── belongs_to :giro (raggruppamento consegne)
├── has_many :events (tracking modifiche)
└── include Golden, Closeable, Postponable, Triageable
```

### Vantaggi
- **Una sola tabella `entries`** per tutti i metadati condivisi
- **Tabelle separate** per dati specifici (appunti, documenti, tappe)
- **Query unificate** su tutte le consegne
- **Nuovi tipi** senza modificare la tabella entries
- **Eventi unificati** per tracking modifiche

### Struttura tabelle

```ruby
# Tabella principale (metadati condivisi)
create_table :entries, id: :uuid do |t|
  # Delegated Type
  t.string :entryable_type, null: false
  t.uuid :entryable_id, null: false

  # Triage
  t.references :column, type: :uuid, foreign_key: true

  # Raggruppamento
  t.references :giro, type: :uuid, foreign_key: true

  # Multi-tenancy
  t.references :user, type: :uuid, foreign_key: true
  t.references :account, type: :uuid, foreign_key: true

  t.timestamps
end
add_index :entries, [:entryable_type, :entryable_id], unique: true

# Tabella colonne (fasi)
create_table :columns, id: :uuid do |t|
  t.string :name, null: false
  t.string :color, default: "#6366f1"
  t.integer :position, default: 0
  t.references :account, type: :uuid, foreign_key: true
  t.timestamps
end

# Tabella eventi (tracking)
create_table :events, id: :uuid do |t|
  t.references :entry, type: :uuid, foreign_key: true
  t.references :user, type: :uuid, foreign_key: true
  t.string :action, null: false  # "triaged", "closed", "gilded", etc.
  t.jsonb :particulars, default: {}
  t.timestamps
end
```

---

## Fase 1: Migrazioni Database
**Skill: `/migration-agent`**

### 1.1 Crea tabella entries
```ruby
class CreateEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :entries, id: :uuid do |t|
      t.string :entryable_type, null: false
      t.uuid :entryable_id, null: false
      t.references :column, type: :uuid, foreign_key: true
      t.references :giro, type: :uuid, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.references :account, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :entries, [:entryable_type, :entryable_id], unique: true
    add_index :entries, [:account_id, :entryable_type]
  end
end
```

### 1.2 Crea tabella columns
```ruby
class CreateColumns < ActiveRecord::Migration[8.0]
  def change
    create_table :columns, id: :uuid do |t|
      t.string :name, null: false
      t.string :color, default: "#6366f1"
      t.integer :position, default: 0
      t.references :account, type: :uuid, foreign_key: true
      t.timestamps
    end
    add_index :columns, [:account_id, :position]
  end
end
```

### 1.3 Crea tabella events
```ruby
class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events, id: :uuid do |t|
      t.references :entry, type: :uuid, foreign_key: true
      t.references :user, type: :uuid, foreign_key: true
      t.references :account, type: :uuid, foreign_key: true
      t.string :action, null: false
      t.jsonb :particulars, default: {}
      t.timestamps
    end
    add_index :events, [:entry_id, :created_at]
    add_index :events, [:account_id, :action]
  end
end
```

### 1.4 Migra state records a polimorfici su Entry
```ruby
# Se goldnesses, closures, not_nows non sono già polimorfici
class MakeStateRecordsPolymorphicOnEntry < ActiveRecord::Migration[8.0]
  def change
    # Goldnesses
    add_column :goldnesses, :entry_id, :uuid
    add_foreign_key :goldnesses, :entries
    add_index :goldnesses, :entry_id, unique: true

    # Closures
    add_column :closures, :entry_id, :uuid
    add_foreign_key :closures, :entries
    add_index :closures, :entry_id, unique: true

    # NotNows
    add_column :not_nows, :entry_id, :uuid
    add_foreign_key :not_nows, :entries
    add_index :not_nows, :entry_id, unique: true
  end
end
```

### 1.5 Rinomina Consegne → Appunto::Sospensioni
```ruby
class RenameConsegneToAppuntoSospensioni < ActiveRecord::Migration[8.0]
  def change
    rename_table :consegne, :appunto_sospensioni
    rename_column :appunto_sospensioni, :consegnato_il, :sospeso_il
  end
end
```

---

## Fase 2: Model Entry (Delegated Types)
**Skill: `/model-agent`**

### 2.1 Entry model
```ruby
# app/models/entry.rb
class Entry < ApplicationRecord
  # Delegated Type
  delegated_type :entryable, types: %w[Appunto Documento Tappa], dependent: :destroy

  # Associations
  belongs_to :column, optional: true
  belongs_to :giro, optional: true
  belongs_to :user
  belongs_to :account

  has_many :events, dependent: :destroy

  # State records
  has_one :goldness, dependent: :destroy
  has_one :closure, dependent: :destroy
  has_one :not_now, dependent: :destroy

  # Scopes
  scope :awaiting_triage, -> { active.where(column_id: nil) }
  scope :triaged, -> { active.where.not(column_id: nil) }
  scope :active, -> { open.where.missing(:not_now) }
  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }
  scope :postponed, -> { joins(:not_now) }
  scope :golden, -> { joins(:goldness) }

  # Convenience scopes per tipo
  scope :appunti, -> { where(entryable_type: "Appunto") }
  scope :documenti, -> { where(entryable_type: "Documento") }
  scope :tappe, -> { where(entryable_type: "Tappa") }

  # Per giro
  scope :for_giro, ->(giro) { where(giro: giro) }
  scope :without_giro, -> { where(giro_id: nil) }
end
```

### 2.2 Concern Entryable (shared)
```ruby
# app/models/concerns/entryable.rb
module Entryable
  extend ActiveSupport::Concern

  included do
    has_one :entry, as: :entryable, touch: true, dependent: :destroy

    # Delegate common methods to entry
    delegate :column, :giro, :golden?, :closed?, :postponed?,
             :triaged?, :awaiting_triage?, to: :entry, allow_nil: true
  end

  # Create entry automatically
  def ensure_entry!(user:, account:)
    entry || create_entry!(user: user, account: account)
  end
end
```

### 2.3 Concern Triageable (su Entry)
```ruby
# app/models/concerns/entry/triageable.rb
module Entry::Triageable
  extend ActiveSupport::Concern

  def triage_into(column)
    transaction do
      resume if postponed?
      update!(column: column)
      track_event :triaged, particulars: { column: column.name }
    end
  end

  def send_back_to_triage
    transaction do
      resume if postponed?
      update!(column: nil)
      track_event :sent_back_to_triage
    end
  end
end
```

### 2.4 Concern Eventable (su Entry)
```ruby
# app/models/concerns/entry/eventable.rb
module Entry::Eventable
  extend ActiveSupport::Concern

  def track_event(action, creator: Current.user, particulars: {})
    events.create!(
      action: action.to_s,
      user: creator,
      account: account,
      particulars: particulars
    )
    touch_last_active_at
  end

  private

  def touch_last_active_at
    touch
  end
end
```

### 2.5 Concern Golden, Closeable, Postponable (su Entry)
```ruby
# app/models/concerns/entry/golden.rb
module Entry::Golden
  extend ActiveSupport::Concern

  def gild(user: Current.user)
    return if golden?
    create_goldness!(user: user)
    track_event :gilded
  end

  def ungild
    return unless golden?
    goldness.destroy
    track_event :ungilded
  end

  def golden?
    goldness.present?
  end
end

# app/models/concerns/entry/closeable.rb
module Entry::Closeable
  extend ActiveSupport::Concern

  def close(user: Current.user)
    return if closed?
    transaction do
      not_now&.destroy
      create_closure!(user: user)
      track_event :closed
    end
  end

  def reopen(user: Current.user)
    return unless closed?
    closure.destroy
    track_event :reopened
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end
end

# app/models/concerns/entry/postponable.rb
module Entry::Postponable
  extend ActiveSupport::Concern

  def postpone(user: Current.user)
    return if postponed?
    transaction do
      send_back_to_triage
      create_not_now!(user: user)
      track_event :postponed
    end
  end

  def resume
    return unless postponed?
    not_now.destroy
  end

  def postponed?
    not_now.present?
  end

  def active?
    open? && !postponed?
  end
end
```

### 2.6 Aggiorna Appunto, Documento, Tappa
```ruby
# app/models/appunto.rb
class Appunto < ApplicationRecord
  include Entryable

  # Concern specifici Appunto
  include InSospeso  # Appunto::Sospensione

  # Relazioni esistenti
  has_many :appunto_righe
  has_many :righe, through: :appunto_righe
  # ... resto del model
end

# app/models/documento.rb
class Documento < ApplicationRecord
  include Entryable

  # Concern specifici Documento
  include Pagabile       # Documento::Pagamento
  include Consegnabile   # Documento::Consegna
  include Registrabile   # Documento::Registrazione

  # ... resto del model
end

# app/models/tappa.rb
class Tappa < ApplicationRecord
  include Entryable

  # Relazioni esistenti
  belongs_to :tappable, polymorphic: true, optional: true
  has_many :tappa_giri
  has_many :giri, through: :tappa_giri
  # ... resto del model
end
```

---

## Fase 3: Model Supporto
**Skill: `/model-agent`**

### 3.1 Column model
```ruby
# app/models/column.rb
class Column < ApplicationRecord
  belongs_to :account
  has_many :entries

  acts_as_list scope: :account

  scope :positioned, -> { order(:position) }

  # Colonne default per account
  DEFAULT_COLUMNS = [
    { name: "Consegna Collana", color: "#22c55e" },
    { name: "Ritiro Collana", color: "#f97316" },
    { name: "Consegna Vacanze", color: "#3b82f6" },
    { name: "Ritiro Vacanze", color: "#8b5cf6" }
  ].freeze

  def self.create_defaults_for(account)
    DEFAULT_COLUMNS.each_with_index do |attrs, index|
      account.columns.find_or_create_by!(name: attrs[:name]) do |col|
        col.color = attrs[:color]
        col.position = index
      end
    end
  end
end
```

### 3.2 Event model
```ruby
# app/models/event.rb
class Event < ApplicationRecord
  belongs_to :entry
  belongs_to :user, optional: true
  belongs_to :account

  scope :recent, -> { order(created_at: :desc) }
  scope :for_action, ->(action) { where(action: action) }

  # Actions comuni
  ACTIONS = %w[
    triaged sent_back_to_triage
    gilded ungilded
    closed reopened
    postponed
    created updated
  ].freeze
end
```

### 3.3 State records aggiornati
```ruby
# app/models/goldness.rb
class Goldness < ApplicationRecord
  belongs_to :entry
  belongs_to :user, optional: true
end

# app/models/closure.rb
class Closure < ApplicationRecord
  belongs_to :entry
  belongs_to :user, optional: true
end

# app/models/not_now.rb
class NotNow < ApplicationRecord
  belongs_to :entry
  belongs_to :user, optional: true
end
```

---

## Fase 4: Routes e Controllers
**Skill: `/crud-agent`**

### 4.1 Routes
```ruby
# config/routes.rb

# Entries triage (unified)
resources :entries, only: [] do
  scope module: :entries do
    resource :goldness,  only: [:create, :destroy]
    resource :closure,   only: [:create, :destroy]
    resource :not_now,   only: [:create, :destroy]
    resource :triage,    only: [:create, :destroy]
  end
end

# Columns management
resources :columns, except: [:show]

# Existing resources with entry creation
resources :appunti do
  # Concern specifici
  scope module: :appunti do
    resource :sospensione, only: [:create, :destroy]
  end
end

resources :documenti do
  # Concern specifici
  scope module: :documenti do
    resource :pagamento,     only: [:create, :destroy]
    resource :consegna,      only: [:create, :destroy]
    resource :registrazione, only: [:create, :destroy]
  end
end
```

### 4.2 EntriesController base
```ruby
# app/controllers/entries_controller.rb
class EntriesController < ApplicationController
  before_action :set_entry

  private

  def set_entry
    @entry = current_account.entries.find(params[:entry_id])
  end

  def respond_with_turbo_or_redirect
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: root_path }
    end
  end
end
```

### 4.3 Entries::TriagesController
```ruby
# app/controllers/entries/triages_controller.rb
module Entries
  class TriagesController < EntriesController
    def create
      column = current_account.columns.find(params[:column_id])
      @entry.triage_into(column)
      respond_with_turbo_or_redirect
    end

    def destroy
      @entry.send_back_to_triage
      respond_with_turbo_or_redirect
    end
  end
end
```

### 4.4 Altri controllers entries/*
```ruby
# app/controllers/entries/goldnesses_controller.rb
module Entries
  class GoldnessesController < EntriesController
    def create
      @entry.gild
      respond_with_turbo_or_redirect
    end

    def destroy
      @entry.ungild
      respond_with_turbo_or_redirect
    end
  end
end

# Stesso pattern per closures, not_nows
```

---

## Fase 5: Vista Kanban Unificata
**Skill: `/turbo-agent` + `/stimulus-agent`**

### 5.1 Dashboard index (tutte le entries)
```erb
<%# app/views/dashboard/index.html.erb %>
<%= render "shared/kanban_board",
    columns: @columns,
    awaiting_triage: @awaiting_triage,
    postponed: @postponed,
    closed: @closed %>
```

### 5.2 Controller dashboard
```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  def index
    @columns = current_account.columns.positioned
    @awaiting_triage = current_account.entries.awaiting_triage.includes(:entryable)
    @postponed = current_account.entries.postponed.includes(:entryable)
    @closed = current_account.entries.closed.recent.limit(20).includes(:entryable)
  end
end
```

### 5.3 Partial entry (polymorphic rendering)
```erb
<%# app/views/entries/_entry.html.erb %>
<article class="card"
         id="<%= dom_id(entry) %>"
         draggable="true"
         data-entry-id="<%= entry.id %>"
         data-entry-type="<%= entry.entryable_type.downcase %>">

  <div class="card__type-badge card__type-badge--<%= entry.entryable_type.downcase %>">
    <%= entry.entryable_type %>
  </div>

  <%# Render del contenuto specifico %>
  <%= render entry.entryable %>

  <footer class="card__meta">
    <% if entry.golden? %>
      <span class="badge badge--golden">★</span>
    <% end %>
    <% if entry.giro.present? %>
      <span class="badge"><%= entry.giro.titolo %></span>
    <% end %>
  </footer>
</article>
```

### 5.4 Partial Kanban board
```erb
<%# app/views/shared/_kanban_board.html.erb %>
<div class="card-columns" data-controller="drag-and-drop">
  <%# Left: Rimandati %>
  <aside class="card-columns__left">
    <div class="card-column card-column--not-now"
         data-drag-and-drop-target="container"
         data-url="<%= entry_not_now_path('__id__') %>">
      <h3>Rimandati (<%= postponed.size %>)</h3>
      <div id="postponed_entries">
        <%= render postponed %>
      </div>
    </div>
  </aside>

  <%# Center: Da gestire %>
  <section class="card-columns__center">
    <div class="card-column card-column--maybe"
         data-drag-and-drop-target="container"
         data-url="<%= entry_triage_path('__id__') %>"
         data-method="delete">
      <h3>Da gestire (<%= awaiting_triage.size %>)</h3>
      <div id="awaiting_triage_entries">
        <%= render awaiting_triage %>
      </div>
    </div>
  </section>

  <%# Right: Colonne fasi + Chiusi %>
  <aside class="card-columns__right">
    <% columns.each do |column| %>
      <div class="card-column"
           style="--column-color: <%= column.color %>"
           data-drag-and-drop-target="container"
           data-url="<%= entry_triage_path('__id__', column_id: column.id) %>">
        <h3><%= column.name %> (<%= column.entries.count %>)</h3>
        <div id="column_<%= column.id %>_entries">
          <%= render column.entries.includes(:entryable) %>
        </div>
      </div>
    <% end %>

    <div class="card-column card-column--done"
         data-drag-and-drop-target="container"
         data-url="<%= entry_closure_path('__id__') %>">
      <h3>Chiusi (<%= closed.size %>)</h3>
      <div id="closed_entries">
        <%= render closed %>
      </div>
    </div>
  </aside>
</div>
```

---

## Fase 6: Turbo Streams
**Skill: `/turbo-agent`**

```erb
<%# app/views/entries/triages/create.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@entry) %>
<%= turbo_stream.prepend "column_#{@entry.column_id}_entries" do %>
  <%= render @entry %>
<% end %>

<%# app/views/entries/triages/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@entry) %>
<%= turbo_stream.prepend "awaiting_triage_entries" do %>
  <%= render @entry %>
<% end %>
```

---

## Fase 7: Migrazione Dati Esistenti (SQL)
**Skill: `/migration-agent`**

⚠️ **IMPORTANTE**: Dati in produzione! Usare SQL per migrare i dati esistenti.

```ruby
class MigrateExistingRecordsToEntries < ActiveRecord::Migration[8.0]
  def up
    # Crea Entry per ogni Appunto esistente
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Appunto',
        id,
        user_id,
        account_id,
        created_at,
        updated_at
      FROM appunti
      WHERE NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Appunto'
        AND entries.entryable_id = appunti.id
      );
    SQL

    # Crea Entry per ogni Documento esistente
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, user_id, account_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Documento',
        id,
        user_id,
        account_id,
        created_at,
        updated_at
      FROM documenti
      WHERE NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Documento'
        AND entries.entryable_id = documenti.id
      );
    SQL

    # Crea Entry per ogni Tappa esistente
    execute <<-SQL
      INSERT INTO entries (id, entryable_type, entryable_id, user_id, account_id, giro_id, created_at, updated_at)
      SELECT
        gen_random_uuid(),
        'Tappa',
        t.id,
        t.user_id,
        t.account_id,
        (SELECT tg.giro_id FROM tappa_giri tg WHERE tg.tappa_id = t.id LIMIT 1),
        t.created_at,
        t.updated_at
      FROM tappe t
      WHERE NOT EXISTS (
        SELECT 1 FROM entries
        WHERE entries.entryable_type = 'Tappa'
        AND entries.entryable_id = t.id
      );
    SQL

    # Migra goldnesses esistenti (se hanno appunto_id o simili)
    # Prima verifica la struttura attuale della tabella
    if column_exists?(:goldnesses, :goldenable_id)
      execute <<-SQL
        UPDATE goldnesses g
        SET entry_id = e.id
        FROM entries e
        WHERE e.entryable_type = g.goldenable_type
        AND e.entryable_id = g.goldenable_id
        AND g.entry_id IS NULL;
      SQL
    end

    # Migra closures esistenti
    if column_exists?(:closures, :closeable_id)
      execute <<-SQL
        UPDATE closures c
        SET entry_id = e.id
        FROM entries e
        WHERE e.entryable_type = c.closeable_type
        AND e.entryable_id = c.closeable_id
        AND c.entry_id IS NULL;
      SQL
    end

    # Migra not_nows esistenti
    if column_exists?(:not_nows, :not_nowable_id)
      execute <<-SQL
        UPDATE not_nows n
        SET entry_id = e.id
        FROM entries e
        WHERE e.entryable_type = n.not_nowable_type
        AND e.entryable_id = n.not_nowable_id
        AND n.entry_id IS NULL;
      SQL
    end
  end

  def down
    # Rimuovi solo le entries, mantieni i dati originali
    execute "DELETE FROM entries;"

    # Rimuovi entry_id dai state records
    execute "UPDATE goldnesses SET entry_id = NULL;" if column_exists?(:goldnesses, :entry_id)
    execute "UPDATE closures SET entry_id = NULL;" if column_exists?(:closures, :entry_id)
    execute "UPDATE not_nows SET entry_id = NULL;" if column_exists?(:not_nows, :entry_id)
  end
end
```

### 7.1 Migrazione Consegne → Appunto::Sospensioni (con dati)
```ruby
class RenameConsegneToAppuntoSospensioni < ActiveRecord::Migration[8.0]
  def up
    # Rinomina tabella
    rename_table :consegne, :appunto_sospensioni

    # Rinomina colonna
    rename_column :appunto_sospensioni, :consegnato_il, :sospeso_il

    # Se la colonna polimorphica era consegnabile_id, rinominala
    if column_exists?(:appunto_sospensioni, :consegnabile_id)
      rename_column :appunto_sospensioni, :consegnabile_id, :appunto_id
      rename_column :appunto_sospensioni, :consegnabile_type, :legacy_type

      # Rimuovi record non-Appunto (se ce ne sono)
      execute <<-SQL
        DELETE FROM appunto_sospensioni
        WHERE legacy_type IS NOT NULL AND legacy_type != 'Appunto';
      SQL

      # Rimuovi colonna legacy
      remove_column :appunto_sospensioni, :legacy_type
    end
  end

  def down
    rename_column :appunto_sospensioni, :sospeso_il, :consegnato_il
    rename_table :appunto_sospensioni, :consegne
  end
end
```

### 7.2 Crea colonne default per account esistenti
```ruby
class CreateDefaultColumnsForExistingAccounts < ActiveRecord::Migration[8.0]
  def up
    Account.find_each do |account|
      [
        { name: "Consegna Collana", color: "#22c55e", position: 0 },
        { name: "Ritiro Collana", color: "#f97316", position: 1 },
        { name: "Consegna Vacanze", color: "#3b82f6", position: 2 },
        { name: "Ritiro Vacanze", color: "#8b5cf6", position: 3 }
      ].each do |attrs|
        execute <<-SQL
          INSERT INTO columns (id, name, color, position, account_id, created_at, updated_at)
          VALUES (
            gen_random_uuid(),
            '#{attrs[:name]}',
            '#{attrs[:color]}',
            #{attrs[:position]},
            '#{account.id}',
            NOW(),
            NOW()
          )
          ON CONFLICT DO NOTHING;
        SQL
      end
    end
  end

  def down
    execute "DELETE FROM columns WHERE name IN ('Consegna Collana', 'Ritiro Collana', 'Consegna Vacanze', 'Ritiro Vacanze');"
  end
end
```

---

## Struttura File Finale

```
app/
├── models/
│   ├── entry.rb                    # Delegated Type superclass
│   ├── column.rb                   # Fasi consegna/ritiro
│   ├── event.rb                    # Tracking eventi
│   │
│   ├── # State records (su Entry)
│   ├── goldness.rb
│   ├── closure.rb
│   ├── not_now.rb
│   │
│   ├── # Entryables (delegated types)
│   ├── appunto.rb                  # include Entryable
│   ├── documento.rb                # include Entryable
│   ├── tappa.rb                    # include Entryable
│   │
│   ├── # Model specifici (namespaced)
│   ├── appunto/
│   │   └── sospensione.rb
│   ├── documento/
│   │   ├── pagamento.rb
│   │   ├── consegna.rb
│   │   └── registrazione.rb
│   │
│   └── concerns/
│       ├── entryable.rb            # Shared per tutti i tipi
│       ├── entry/
│       │   ├── triageable.rb
│       │   ├── eventable.rb
│       │   ├── golden.rb
│       │   ├── closeable.rb
│       │   └── postponable.rb
│       │
│       ├── # Concern specifici
│       ├── in_sospeso.rb           # Appunto
│       ├── pagabile.rb             # Documento
│       ├── consegnabile.rb         # Documento
│       └── registrabile.rb         # Documento
│
├── controllers/
│   ├── dashboard_controller.rb     # Vista kanban unificata
│   ├── entries_controller.rb       # Base
│   ├── entries/
│   │   ├── triages_controller.rb
│   │   ├── goldnesses_controller.rb
│   │   ├── closures_controller.rb
│   │   └── not_nows_controller.rb
│   ├── columns_controller.rb
│   ├── appunti/
│   │   └── sospensioni_controller.rb
│   └── documenti/
│       ├── pagamenti_controller.rb
│       ├── consegne_controller.rb
│       └── registrazioni_controller.rb
│
└── views/
    ├── shared/
    │   ├── _kanban_board.html.erb
    │   └── _kanban_column.html.erb
    ├── entries/
    │   ├── _entry.html.erb
    │   └── triages/
    │       └── *.turbo_stream.erb
    ├── dashboard/
    │   └── index.html.erb
    └── columns/
        └── *.html.erb
```

---

## Verifica

1. `docker exec -it prova-app-1 bin/rails db:migrate`
2. Verificare che entries vengano create per record esistenti
3. Creare colonne default per account
4. Testare drag & drop tra colonne
5. Testare stati: golden, closed, postponed
6. Verificare eventi vengano tracciati
7. `docker exec -it prova-app-1 bin/rails test`

---

## Note Importanti

1. **Entry è il punto di accesso** - Tutte le operazioni di triage passano da Entry
2. **Entryable è "dumb"** - Appunto/Documento/Tappa contengono solo dati specifici
3. **Backward compatible** - Il codice esistente continua a funzionare
4. **Query unificate** - `Entry.appunti.triaged` oppure `Entry.for_giro(giro)`
5. **Giro opzionale** - Entry può avere o meno un giro associato
6. **Colonne per account** - Ogni account ha le sue colonne/fasi

---

## ⚠️ Strategia Migrazione Production

**Ordine delle migrazioni:**
1. Crea nuove tabelle (entries, columns, events)
2. Aggiungi colonne entry_id ai state records esistenti
3. Popola entries da appunti, documenti, tappe (SQL INSERT)
4. Aggiorna state records con entry_id (SQL UPDATE)
5. Rinomina consegne → appunto_sospensioni
6. Crea colonne default per account

**Rollback sicuro:**
- Ogni migrazione ha `down` method
- I dati originali non vengono mai cancellati
- Entry può essere rimossa senza perdere appunti/documenti/tappe

**Testing pre-produzione:**
```bash
# Dump del database
pg_dump -Fc production_db > backup.dump

# Restore su staging
pg_restore -d staging_db backup.dump

# Esegui migrazioni su staging
docker exec -it staging-app bin/rails db:migrate

# Verifica integrità dati
docker exec -it staging-app bin/rails runner "
  puts 'Appunti: ' + Appunto.count.to_s
  puts 'Entries appunti: ' + Entry.appunti.count.to_s
  puts 'Match: ' + (Appunto.count == Entry.appunti.count).to_s
"
```
