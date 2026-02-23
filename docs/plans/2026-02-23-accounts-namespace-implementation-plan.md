# Accounts:: Namespace Refactoring — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move account-management models (AccountZona, Mandato, Membership, MembershipScuola), controllers, and views under the `Accounts::` namespace for better code organization, without changing URLs or database tables.

**Architecture:** Ruby-only namespace refactoring. Models get `self.table_name` to keep existing tables. Controllers move under `Accounts::` module. Routes use `namespace :accounts, path: ""` to preserve URLs. Views move to `app/views/accounts/` subdirectories.

**Tech Stack:** Rails 8, PostgreSQL, Turbo Streams, Minitest

**Design doc:** `docs/plans/2026-02-23-accounts-namespace-design.md`

**Docker prefix:** All Rails/test commands run via `docker exec prova-app-1`

---

## Task 1: Accounts::Zona model (ex AccountZona)

**Files:**
- Create: `app/models/accounts/zona.rb`
- Create: `app/models/concerns/accounts/zona/gestione_stato.rb`
- Modify: `app/models/account.rb:23` — update association
- Modify: `app/models/concerns/account/gestione_mandati.rb:6` — `account_zone` → `zone`
- Modify: `app/jobs/count_scuole_per_zona_job.rb` — update class reference
- Modify: `app/jobs/cleanup_zona_job.rb` — update class reference
- Modify: `app/jobs/import_scuole_per_zona_job.rb` — update class reference
- Delete: `app/models/account_zona.rb` (after creating new file)
- Delete: `app/models/concerns/account_zona/gestione_stato.rb`
- Test: `test/models/account_zona_test.rb` → update references

**Step 1: Create the namespaced model**

Create `app/models/accounts/zona.rb`:

```ruby
module Accounts
  class Zona < ApplicationRecord
    self.table_name = "account_zone"

    include AccountScoped
    include Accounts::Zona::GestioneStato

    belongs_to :account

    validates :provincia, presence: true
    validates :grado, presence: true
    validates :provincia, uniqueness: { scope: [:account_id, :grado, :anno_scolastico] }

    after_create_commit :count_scuole_async

    scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
    scope :pronte, -> { where(stato: "pronta") }
    scope :da_rimuovere, -> { where(stato: "da_rimuovere") }

    def grado_label
      TipoScuola::GRADI.to_h.invert[grado] || grado
    end

    def scuole_importate_count
      account.scuole.where(provincia: provincia, grado: grado).count
    end

    def parziale?
      stato == "attiva" && scuole_importate_count < scuole_count
    end

    def import_scuole_per_zona
      tipi = TipoScuola.where(grado: grado).pluck(:tipo)
      ImportScuola.where(PROVINCIA: provincia, DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipi)
    end

    private

    def count_scuole_async
      CountScuolePerZonaJob.perform_later(self)
    end
  end
end
```

**Step 2: Create the namespaced concern**

Create `app/models/concerns/accounts/zona/gestione_stato.rb`:

```ruby
module Accounts::Zona::GestioneStato
  extend ActiveSupport::Concern

  def toggle_rimozione!
    case stato
    when "pronta", "conteggio"
      destroy!
    when "da_rimuovere"
      update!(stato: "attiva")
    else
      update!(stato: "da_rimuovere")
    end
  end
end
```

**Step 3: Update Account model association**

In `app/models/account.rb`, change:
```ruby
has_many :account_zone, class_name: "AccountZona", dependent: :destroy
```
to:
```ruby
has_many :zone, class_name: "Accounts::Zona", dependent: :destroy
```

Also update `add_zone!` method: change `account_zone.find_or_create_by!` to `zone.find_or_create_by!`.

**Step 4: Update Account::GestioneMandati concern**

In `app/models/concerns/account/gestione_mandati.rb`, change:
```ruby
target_zone = account_zone.where(stato: "attiva")
```
to:
```ruby
target_zone = zone.where(stato: "attiva")
```

**Step 5: Update jobs**

In each job file, find references to `AccountZona` and replace with `Accounts::Zona`. Check parameter types in `perform` methods — if they use GlobalID (Active Job argument serialization), class name changes are handled automatically by Rails.

- `app/jobs/count_scuole_per_zona_job.rb` — parameter is already passed as object (GlobalID resolves automatically)
- `app/jobs/cleanup_zona_job.rb` — check for any `AccountZona` string references
- `app/jobs/import_scuole_per_zona_job.rb` — check for any `AccountZona` string references

**Step 6: Update test file**

In `test/models/account_zona_test.rb`, update class references from `AccountZona` to `Accounts::Zona`.

**Step 7: Delete old files**

```bash
rm app/models/account_zona.rb
rm -rf app/models/concerns/account_zona/
```

**Step 8: Run tests**

```bash
docker exec prova-app-1 bin/rails test test/models/account_zona_test.rb
docker exec prova-app-1 bin/rails test test/jobs/
```

**Step 9: Commit**

```bash
git add -A && git commit -m "refactor: move AccountZona to Accounts::Zona namespace"
```

---

## Task 2: Accounts::Mandato model (ex Mandato)

**Files:**
- Create: `app/models/accounts/mandato.rb`
- Delete: `app/models/mandato.rb`
- Modify: `app/models/account.rb:24` — update association
- Modify: `app/jobs/update_mie_adozioni_job.rb` — check references
- Test: `test/models/mandato_test.rb` — update references

**Step 1: Create the namespaced model**

Create `app/models/accounts/mandato.rb`:

```ruby
module Accounts
  class Mandato < ApplicationRecord
    self.table_name = "mandati"

    include AccountScoped

    belongs_to :editore

    validates :editore_id, uniqueness: { scope: [:account_id, :provincia, :grado, :anno_scolastico] }

    scope :attivi, -> { where(disdetta: false) }
    scope :disdetti, -> { where(disdetta: true) }

    after_commit :update_mie_adozioni_async, on: [:create, :destroy]
    after_update_commit :update_mie_adozioni_async, if: :saved_change_to_disdetta?

    def copre_scuola?(scuola)
      (provincia.nil? || provincia == scuola.provincia) &&
        (grado.nil? || grado == scuola.grado)
    end

    private

    def update_mie_adozioni_async
      UpdateMieAdozioniJob.perform_later(account)
    end
  end
end
```

**Step 2: Update Account model**

In `app/models/account.rb`, change:
```ruby
has_many :mandati, dependent: :destroy
```
to:
```ruby
has_many :mandati, class_name: "Accounts::Mandato", dependent: :destroy
```

**Step 3: Update jobs and grep for `Mandato` references**

Search all files for bare `Mandato` references (excluding migrations). The SQL in `update_mie_adozioni_job.rb` references the `mandati` table directly (not the model class), so it should work without changes. But verify.

**Step 4: Delete old file**

```bash
rm app/models/mandato.rb
```

**Step 5: Run tests**

```bash
docker exec prova-app-1 bin/rails test test/models/mandato_test.rb
docker exec prova-app-1 bin/rails test test/jobs/
```

**Step 6: Commit**

```bash
git add -A && git commit -m "refactor: move Mandato to Accounts::Mandato namespace"
```

---

## Task 3: Accounts::Membership + Accounts::MembershipScuola models

**Files:**
- Create: `app/models/accounts/membership.rb`
- Create: `app/models/accounts/membership_scuola.rb`
- Create: `app/models/concerns/accounts/membership/scuole_assegnabili.rb`
- Delete: `app/models/membership.rb`
- Delete: `app/models/membership_scuola.rb`
- Delete: `app/models/concerns/membership/scuole_assegnabili.rb`
- Modify: `app/models/account.rb:19-20` — update associations
- Modify: `app/models/user.rb:38` — update association
- Modify: `app/models/scuola.rb:60-61` — update associations
- Modify: `app/models/access_token.rb:19` — update association
- Modify: `app/models/current.rb` — update references
- Modify: `app/models/concerns/account/distribuzione.rb:34` — update `MembershipScuola` reference
- Modify: `app/controllers/concerns/account_from_url.rb` — update `Membership` reference
- Modify: `app/controllers/concerns/passwordless_authentication.rb` — update reference

**Step 1: Create Accounts::MembershipScuola**

Create `app/models/accounts/membership_scuola.rb`:

```ruby
module Accounts
  class MembershipScuola < ApplicationRecord
    self.table_name = "membership_scuole"

    belongs_to :membership, class_name: "Accounts::Membership"
    belongs_to :scuola

    validates :scuola_id, uniqueness: { scope: :membership_id }
  end
end
```

**Step 2: Create Accounts::Membership::ScuoleAssegnabili concern**

Create `app/models/concerns/accounts/membership/scuole_assegnabili.rb`:

```ruby
module Accounts::Membership::ScuoleAssegnabili
  extend ActiveSupport::Concern

  def assegna_scuole!(scuole, da: nil)
    da.rimuovi_scuole!(scuole) if da
    scuole.each { |s| membership_scuole.find_or_create_by!(scuola: s) }
    self.class.sync_direzioni_for(scuole, account: account)
  end

  def rimuovi_scuole!(scuole)
    membership_scuole.where(scuola: scuole).destroy_all
    self.class.sync_direzioni_for(scuole, account: account)
  end

  class_methods do
    def sync_direzioni_for(scuole, account:)
      scuola_ids = scuole.map(&:id)

      dir_ids = account.scuole
        .where.not(direzione_id: nil)
        .where(direzione_id: scuola_ids)
        .distinct.pluck(:direzione_id) & scuola_ids

      dir_ids.each do |dir_id|
        plesso_ids = account.scuole.where(direzione_id: dir_id).pluck(:id)
        mids_con_plessi = Accounts::MembershipScuola.where(scuola_id: plesso_ids).distinct.pluck(:membership_id)

        mids_con_plessi.each do |mid|
          Accounts::MembershipScuola.find_or_create_by!(membership_id: mid, scuola_id: dir_id)
        end

        Accounts::MembershipScuola.where(scuola_id: dir_id)
          .where.not(membership_id: mids_con_plessi)
          .destroy_all
      end
    end
  end
end
```

**Step 3: Create Accounts::Membership**

Create `app/models/accounts/membership.rb`:

```ruby
module Accounts
  class Membership < ApplicationRecord
    self.table_name = "memberships"

    include Accounts::Membership::ScuoleAssegnabili

    belongs_to :user
    belongs_to :account

    enum :role, { member: 0, admin: 1, owner: 2 }

    has_many :access_tokens, dependent: :destroy
    has_many :membership_scuole, class_name: "Accounts::MembershipScuola", dependent: :destroy
    has_many :scuole, through: :membership_scuole

    validates :user_id, uniqueness: { scope: :account_id }
    validates :role, presence: true
  end
end
```

**Step 4: Update all referencing models**

In `app/models/account.rb`:
```ruby
has_many :memberships, class_name: "Accounts::Membership", dependent: :destroy
```

In `app/models/user.rb`:
```ruby
has_many :memberships, class_name: "Accounts::Membership", dependent: :destroy
has_many :accounts, through: :memberships
```

In `app/models/scuola.rb`:
```ruby
has_many :membership_scuole, class_name: "Accounts::MembershipScuola", dependent: :destroy
has_many :memberships, through: :membership_scuole, class_name: "Accounts::Membership"
```

In `app/models/access_token.rb`:
```ruby
belongs_to :membership, class_name: "Accounts::Membership"
```

**Step 5: Update Account::Distribuzione concern**

In `app/models/concerns/account/distribuzione.rb`, change:
```ruby
pairs = MembershipScuola
```
to:
```ruby
pairs = Accounts::MembershipScuola
```

**Step 6: Update controller concerns**

In `app/controllers/concerns/account_from_url.rb` — check for `Membership` references and prefix with `Accounts::`.

In `app/controllers/concerns/passwordless_authentication.rb` — the `memberships.find_by` call goes through the User association, so it should resolve automatically if the `has_many` is updated. Verify.

**Step 7: Delete old files**

```bash
rm app/models/membership.rb
rm app/models/membership_scuola.rb
rm -rf app/models/concerns/membership/
```

**Step 8: Run tests**

```bash
docker exec prova-app-1 bin/rails test test/models/membership_scuola_test.rb
docker exec prova-app-1 bin/rails test test/models/
docker exec prova-app-1 bin/rails test test/controllers/account_members_controller_test.rb
```

**Step 9: Commit**

```bash
git add -A && git commit -m "refactor: move Membership and MembershipScuola to Accounts:: namespace"
```

---

## Task 4: Grep for remaining old class references

**Step 1: Search for stale references**

```bash
docker exec prova-app-1 grep -rn "AccountZona\b" app/ test/ --include="*.rb" --include="*.erb" | grep -v "db/migrate"
docker exec prova-app-1 grep -rn "\bMandato\b" app/ test/ --include="*.rb" --include="*.erb" | grep -v "db/migrate" | grep -v "Accounts::Mandato" | grep -v "LegacyMandato" | grep -v "legacy_mandato"
docker exec prova-app-1 grep -rn "\bMembership\b" app/ test/ --include="*.rb" --include="*.erb" | grep -v "db/migrate" | grep -v "Accounts::Membership"
docker exec prova-app-1 grep -rn "\bMembershipScuola\b" app/ test/ --include="*.rb" --include="*.erb" | grep -v "db/migrate" | grep -v "Accounts::MembershipScuola"
```

**Step 2: Fix any remaining references**

Update each file found in step 1.

**Step 3: Run full test suite**

```bash
docker exec prova-app-1 bin/rails test
```

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: fix remaining old class references after namespace move"
```

---

## Task 5: Move controllers under Accounts:: namespace

**Files to create (from existing controllers):**
- `app/controllers/accounts/zone_controller.rb` — from `app/controllers/zone_controller.rb`
- `app/controllers/accounts/zone/importazioni_controller.rb` — from `app/controllers/zone/importazioni_controller.rb`
- `app/controllers/accounts/mandati_controller.rb` — from `app/controllers/mandati_controller.rb`
- `app/controllers/accounts/mandati/disdetta_controller.rb`
- `app/controllers/accounts/mandati/gruppi_controller.rb`
- `app/controllers/accounts/mandati/gruppi/disdetta_controller.rb`
- `app/controllers/accounts/mandati/sincronizzazione_adozioni_controller.rb`
- `app/controllers/accounts/members_controller.rb` — from `app/controllers/account_members_controller.rb`
- `app/controllers/accounts/members/membership_scuole_controller.rb`
- `app/controllers/accounts/members/bulk_membership_scuole_controller.rb`
- `app/controllers/accounts/distribuzione_controller.rb`
- `app/controllers/accounts/distribuzione/assegnazioni_controller.rb`
- `app/controllers/accounts/configurazione_controller.rb`
- `app/controllers/accounts/aziende_controller.rb`

**Step 1: Create directory structure**

```bash
mkdir -p app/controllers/accounts/zone
mkdir -p app/controllers/accounts/mandati/gruppi
mkdir -p app/controllers/accounts/members
mkdir -p app/controllers/accounts/distribuzione
```

**Step 2: Move each controller**

For each controller, wrap in `module Accounts` and update any internal class references. Example for `ZoneController`:

```ruby
module Accounts
  class ZoneController < ApplicationController
    # ... same body, update AccountZona → Accounts::Zona
  end
end
```

For `AccountMembersController` → rename to `Accounts::MembersController`.

For sub-controllers, update module nesting. Example:
- `Mandati::DisdettaController` → `Accounts::Mandati::DisdettaController`
- `AccountMembers::MembershipScuoleController` → `Accounts::Members::MembershipScuoleController`

**Step 3: Delete old controller files**

```bash
rm app/controllers/zone_controller.rb
rm -rf app/controllers/zone/
rm app/controllers/mandati_controller.rb
rm -rf app/controllers/mandati/
rm app/controllers/account_members_controller.rb
rm -rf app/controllers/account_members/
rm app/controllers/distribuzione_controller.rb
rm -rf app/controllers/distribuzione/
rm app/controllers/configurazione_controller.rb
rm app/controllers/aziende_controller.rb
```

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: move account management controllers to Accounts:: namespace"
```

---

## Task 6: Move views under accounts/ directory

**Step 1: Create directory structure and move views**

```bash
mkdir -p app/views/accounts
mv app/views/zone app/views/accounts/zone
mv app/views/mandati app/views/accounts/mandati
mv app/views/account_members app/views/accounts/members
mv app/views/distribuzione app/views/accounts/distribuzione
mv app/views/configurazione app/views/accounts/configurazione
mv app/views/aziende app/views/accounts/aziende
```

**Step 2: Also move turbo_stream views for sub-controllers if any exist**

Check for views under `zone/importazioni/`, `mandati/disdetta/`, etc. and move them to the correct `accounts/` subdirectory.

**Step 3: Update any `render partial:` calls with hardcoded paths**

Search for render calls that reference old partial paths:
```bash
docker exec prova-app-1 grep -rn "render.*zone/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
docker exec prova-app-1 grep -rn "render.*mandati/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
docker exec prova-app-1 grep -rn "render.*account_members/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
docker exec prova-app-1 grep -rn "render.*distribuzione/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
docker exec prova-app-1 grep -rn "render.*configurazione/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
docker exec prova-app-1 grep -rn "render.*aziende/" app/views/ app/controllers/ app/jobs/ --include="*.rb" --include="*.erb"
```

Update all hardcoded partial paths: `"zone/zone_list"` → `"accounts/zone/zone_list"`, etc.

**Important:** Jobs that broadcast turbo streams with partial rendering (like `CountScuolePerZonaJob`, `ImportScuolePerZonaJob`) need their partial paths updated too.

**Step 4: Commit**

```bash
git add -A && git commit -m "refactor: move account management views to accounts/ directory"
```

---

## Task 7: Update routes

**Step 1: Update config/routes.rb**

Replace the following route blocks (lines ~310-438 area) with the namespaced version. The key change is wrapping zone, mandati, account_members, distribuzione, configurazione, and azienda routes in:

```ruby
namespace :accounts, path: "" do
  # ... routes moved here
end
```

Specifically, extract these route declarations from the `/:account_id` scope and wrap them:

```ruby
# Inside scope "/:account_id" do

namespace :accounts, path: "" do
  resource :configurazione, only: [:show]

  resource :azienda, only: [:show, :new, :create, :edit, :update]

  resources :zone, only: [:index, :new, :create, :destroy] do
    collection do
      resource :importazione, only: [:create], controller: "accounts/zone/importazioni"
    end
  end

  resources :mandati, only: [:index, :create, :destroy] do
    resource :disdetta, only: [:create, :destroy], module: :mandati
    collection do
      get :select_editori
    end
  end

  namespace :mandati do
    resources :gruppi, only: [:destroy], param: :id do
      resource :disdetta, only: [:create, :destroy], module: :gruppi
    end
    resource :sincronizzazione_adozioni, only: [:create]
  end

  resources :members, only: [:create, :update, :destroy] do
    scope module: :members do
      resources :scuole, only: [:create, :destroy], controller: "membership_scuole"
      resource :bulk_scuole, only: [:create, :destroy], controller: "bulk_membership_scuole"
    end
  end

  resource :distribuzione, only: [:show], controller: "distribuzione" do
    resource :assegnazione, only: [:create], controller: "accounts/distribuzione/assegnazioni"
  end
end
```

**Important:** The `path: ""` means URLs stay the same. But path helpers get an `accounts_` prefix. For example:
- `zone_path` → `accounts_zone_path` (or `accounts_zone_index_path`)
- `mandati_path` → `accounts_mandati_path`
- `account_members_path` → `accounts_members_path`
- `configurazione_path` → `accounts_configurazione_path`

**Step 2: Verify routes compile**

```bash
docker exec prova-app-1 bin/rails routes | grep accounts
```

**Step 3: Update all path helper references in views and controllers**

Search for old path helpers and update them. Key helpers to find and replace:

```
configurazione_path → accounts_configurazione_path
zone_path → accounts_zone_index_path (or accounts_zone_path for member)
new_zona_path → new_accounts_zona_path
mandati_path → accounts_mandati_path
mandato_path → accounts_mandato_path
account_members_path → accounts_members_path
account_member_path → accounts_member_path
distribuzione_path → accounts_distribuzione_path
azienda_path → accounts_azienda_path
```

Use `bin/rails routes` output to determine exact new helper names.

**Step 4: Run full test suite**

```bash
docker exec prova-app-1 bin/rails test
```

**Step 5: Commit**

```bash
git add -A && git commit -m "refactor: namespace account management routes under accounts"
```

---

## Task 8: Update Turbo Stream broadcasts and verify

**Step 1: Update broadcast partials in jobs**

Jobs that broadcast turbo streams use partial paths. Update:
- `CountScuolePerZonaJob` — any `render partial:` with zone paths
- `CleanupZonaJob` — any partial render paths
- `ImportScuolePerZonaJob` — any partial render paths

**Step 2: Update broadcast channels if using model-based channels**

If any broadcast uses `broadcasts_to` or `broadcasts_refreshes_to` on the moved models, verify the channel names still work.

**Step 3: Manual smoke test**

Start the app and verify:
1. Configurazione page loads
2. Zone list renders
3. Adding/removing a zona works
4. Mandati list renders
5. Members list renders
6. Distribuzione page loads

**Step 4: Run full test suite one final time**

```bash
docker exec prova-app-1 bin/rails test
```

**Step 5: Commit any final fixes**

```bash
git add -A && git commit -m "fix: turbo stream broadcast paths after namespace refactoring"
```

---

## Task 9: Clean up and verify

**Step 1: Remove any empty old directories**

```bash
rmdir app/controllers/zone 2>/dev/null
rmdir app/controllers/mandati/gruppi 2>/dev/null
rmdir app/controllers/mandati 2>/dev/null
rmdir app/controllers/account_members 2>/dev/null
rmdir app/controllers/distribuzione 2>/dev/null
rmdir app/models/concerns/account_zona 2>/dev/null
rmdir app/models/concerns/membership 2>/dev/null
```

**Step 2: Run annotaterb to update model annotations**

```bash
docker exec prova-app-1 bundle exec annotaterb models
```

**Step 3: Final grep for any old references**

```bash
docker exec prova-app-1 grep -rn "AccountZona\|account_zona\|account_members" app/ --include="*.rb" --include="*.erb" | grep -v "db/migrate" | grep -v "accounts/"
```

**Step 4: Commit**

```bash
git add -A && git commit -m "chore: cleanup after Accounts:: namespace refactoring"
```
