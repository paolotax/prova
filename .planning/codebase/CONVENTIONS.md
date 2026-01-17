# Coding Conventions

**Analysis Date:** 2026-01-17

## Naming Patterns

### Files
- Ruby: `snake_case.rb`
- Models: singular (`libro.rb`, `appunto.rb`, `documento.rb`)
- Controllers: plural (`libri_controller.rb`, `appunti_controller.rb`)
- Concerns: descriptive (`account_scoped.rb`, `filter_scoped.rb`)
- Stimulus: `*_controller.js` (`bulk_actions_controller.js`)
- ViewComponents: `*_component.rb` (`button_component.rb`)

### Domain Terms (Italian)
- Use Italian for domain models: `Libro`, `Appunto`, `Documento`, `Scuola`, `Cliente`, `Editore`
- Use Italian for database tables: `libri`, `appunti`, `documenti`, `scuole`, `clienti`
- Use English for technical patterns: `AccountScoped`, `FilterProxy`, `Searchable`

### Methods
- Ruby: `snake_case`
- Predicate methods: `has_fascicoli?`, `golden?`, `closed?`, `pagato?`
- Action methods: `mark_golden`, `mark_pagato`, `close`, `reopen`
- Private callbacks: `set_account_from_current`, `ricalcola_totali`

### Variables
- Instance: `@libro`, `@appunto`, `@filter`
- Local: `snake_case` (`codice_isbn`, `prezzo_in_cents`)
- Constants: `SCREAMING_SNAKE_CASE` (`FILTER_PARAMS`)

## Code Style

### Ruby
- 2-space indentation
- Use `extend ActiveSupport::Concern` for modules
- Use `included do` block for concern callbacks
- Frozen string literals in components: `# frozen_string_literal: true`

### Model Organization
```ruby
class Libro < ApplicationRecord
  # 1. Concerns
  include AccountScoped
  include Searchable
  extend FilterableModel

  # 2. Associations
  belongs_to :user
  has_many :righe

  # 3. Validations
  validates :titolo, presence: true

  # 4. Scopes
  scope :no_fascicoli, -> { where(fascicoli_count: 0) }

  # 5. Callbacks
  before_save :init

  # 6. Instance methods
  def can_delete?
    # ...
  end

  private

  # 7. Private methods
  def sync_copertina
    # ...
  end
end
```

## Error Handling

```ruby
def create
  @libro = Current.account.libri.build(libro_params)

  respond_to do |format|
    if @libro.save
      format.turbo_stream
      format.html { redirect_to libri_url, notice: "Libro inserito." }
    else
      format.turbo_stream { flash.now[:alert] = "Impossibile creare..." }
      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
```

## Concern Pattern

```ruby
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account
    validates :account_id, presence: true
    before_validation :set_account_from_current, on: :create
    scope :for_account, ->(account) { where(account: account) }
  end

  private

  def set_account_from_current
    self.account ||= Current.account
  end
end
```

## Multi-tenancy Pattern

```ruby
# Current context
Current.user       # Authenticated user
Current.account    # Active tenant
Current.membership # User's role

# In controllers
Current.account.libri.build(params)

# In models
include AccountScoped
```

## Money Handling

```ruby
# Storage: Integer cents
# Field: prezzo_in_cents

def prezzo
  prezzo_in_cents ? prezzo_in_cents / 100.0 : 0.0
end

def prezzo=(value)
  self.prezzo_in_cents = value.present? ? (BigDecimal(value) * 100).to_i : 0
end
```

## Stimulus Controllers

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "counter"]
  static values = { open: Boolean }

  connect() { /* initialization */ }

  toggle(event) { /* public action */ }

  #syncSelection() { /* private helper */ }
}
```

## Comments

- Schema annotations via `annotaterb` at top of models
- Brief explanations for complex SQL
- Italian comments for domain logic
- TODO/FIXME for incomplete work

---

*Convention analysis: 2026-01-17*
