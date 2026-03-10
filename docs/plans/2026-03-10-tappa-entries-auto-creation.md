# Tappa Entries Auto-Creation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically create Entry records for Tappe (visits) so they appear in the kanban and in scuola/cliente entry lists.

**Architecture:** Tappe with `data_tappa` today or past get an Entry (triage). Tappe future don't. A daily job creates entries for today's tappe. When `data_tappa` changes, entries are created or destroyed accordingly. Scuola/Cliente show pages display tappe entries in existing open/closed lists, plus a new "Prossime visite" section for future tappe without entries.

**Tech Stack:** Rails 8.1, Minitest, Solid Queue, Turbo Streams

---

### Task 1: Tappa model — auto-create entry on creation

**Files:**
- Modify: `app/models/tappa.rb`

**Step 1: Add `should_auto_create_entry?` override**

```ruby
# In Tappa, after the Entryable include, add private method:

def should_auto_create_entry?
  data_tappa.present? && data_tappa <= Date.today
end
```

This uses the existing `Entryable` concern's `after_create :create_entry_record, if: :should_auto_create_entry?` callback.

**Step 2: Verify in console**

Run: `docker exec prova-app-1 bin/rails runner "t = Tappa.new(user: User.first, account: Account.first, tappable: Scuola.first, data_tappa: Date.today); t.save!; puts t.entry.present?"`
Expected: `true`

**Step 3: Commit**

```bash
git add app/models/tappa.rb
git commit -m "feat: auto-create entry for tappe with data oggi o passata"
```

---

### Task 2: Tappa model — manage entry on `data_tappa` change

**Files:**
- Modify: `app/models/tappa.rb`

**Step 1: Add after_update callback for data_tappa changes**

```ruby
# In Tappa included block or as callback:
after_update_commit :manage_entry_on_data_change, if: :saved_change_to_data_tappa?

private

def manage_entry_on_data_change
  if data_tappa.present? && data_tappa <= Date.today
    # Tappa moved to today or past — ensure entry exists
    ensure_entry! unless entry.present?
  else
    # Tappa moved to future or planner (nil) — destroy entry
    entry&.destroy
  end
end
```

**Key behavior:**
- Drag tappa to today → creates entry (triage, no column)
- Drag tappa to future date → destroys entry
- Drag tappa to planner (data_tappa = nil) → destroys entry
- Already has entry + moved to another past date → entry stays

**Step 2: Verify sort action works**

The `tappe_controller.rb:158` sort action does `@tappa.update(position: posizione, data_tappa: data_tappa)` — the callback will fire here.

**Step 3: Commit**

```bash
git add app/models/tappa.rb
git commit -m "feat: create/destroy entry when tappa data_tappa changes"
```

---

### Task 3: Extend HasEntries to support Tappe

**Files:**
- Modify: `app/models/concerns/has_entries.rb`
- Modify: `app/models/entry.rb` (scope `for_entryables`)

**Step 1: Extend `for_entryables` scope in Entry**

Current scope only handles Appunto and Documento. Add Tappa support:

```ruby
# In entry.rb, replace the for_entryables scope:
scope :for_entryables, ->(appunto_ids, documento_ids, tappa_ids = []) {
  conditions = []
  conditions << sanitize_sql_array(["(entryable_type = 'Appunto' AND entryable_id IN (?))", appunto_ids]) if appunto_ids.present?
  conditions << sanitize_sql_array(["(entryable_type = 'Documento' AND entryable_id IN (?))", documento_ids]) if documento_ids.present?
  conditions << sanitize_sql_array(["(entryable_type = 'Tappa' AND entryable_id IN (?))", tappa_ids]) if tappa_ids.present?

  if conditions.any?
    where(conditions.join(" OR "))
  else
    none
  end
}
```

**Step 2: Update HasEntries concern**

```ruby
# has_entries.rb — add entry_tappa_ids support:
module HasEntries
  extend ActiveSupport::Concern

  def open_entries
    Entry.where(account: Current.account)
         .aperti
         .for_entryables(entry_appunto_ids, entry_documento_ids, entry_tappa_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end

  def closed_entries
    Entry.where(account: Current.account)
         .closed
         .for_entryables(entry_appunto_ids, entry_documento_ids, entry_tappa_ids)
         .includes(:goldness, :closure, :not_now)
         .order(updated_at: :desc)
  end

  private

  # Default: no tappe. Override in models that have tappe.
  def entry_tappa_ids
    []
  end
end
```

**Step 3: Commit**

```bash
git add app/models/entry.rb app/models/concerns/has_entries.rb
git commit -m "feat: extend HasEntries and for_entryables to support Tappe"
```

---

### Task 4: Add `entry_tappa_ids` to Scuola, Cliente, Classe

**Files:**
- Modify: `app/models/scuola.rb`
- Modify: `app/models/cliente.rb`
- Modify: `app/models/classe.rb`

**Step 1: Scuola**

```ruby
# In scuola.rb private section, add:
def entry_tappa_ids
  tappe.pluck(:id).map(&:to_s)
end
```

Scuola already has `has_many :tappe, as: :tappable` (verify this exists, add if missing).

**Step 2: Cliente**

```ruby
# In cliente.rb private section, add:
def entry_tappa_ids
  tappe.pluck(:id).map(&:to_s)
end
```

Cliente needs `has_many :tappe, as: :tappable` (verify/add).

**Step 3: Classe**

```ruby
# In classe.rb private section, add:
def entry_tappa_ids
  []  # Tappe are linked to Scuola, not Classe
end
```

**Step 4: Commit**

```bash
git add app/models/scuola.rb app/models/cliente.rb app/models/classe.rb
git commit -m "feat: add entry_tappa_ids to Scuola, Cliente, Classe"
```

---

### Task 5: Daily job — create entries for today's tappe

**Files:**
- Create: `app/jobs/create_tappa_entries_job.rb`

**Step 1: Create the job**

```ruby
class CreateTappaEntriesJob < ApplicationJob
  queue_as :default

  def perform
    # Find tappe of today without an entry
    tappa_ids_with_entry = Entry.where(entryable_type: "Tappa").pluck(:entryable_id)

    Tappa.where(data_tappa: Date.today)
         .where.not(id: tappa_ids_with_entry)
         .find_each do |tappa|
      tappa.ensure_entry!
    end
  end
end
```

**Step 2: Schedule with recurring job (Solid Queue)**

Add to `config/recurring.yml`:

```yaml
create_tappa_entries:
  class: CreateTappaEntriesJob
  schedule: every day at 6am
```

**Step 3: Commit**

```bash
git add app/jobs/create_tappa_entries_job.rb config/recurring.yml
git commit -m "feat: daily job to create entries for today's tappe"
```

---

### Task 6: Backfill task — create entries for existing tappe

**Files:**
- Create: `lib/tasks/tappe_entries.rake`

**Step 1: Create rake task**

```ruby
namespace :tappe do
  desc "Backfill: create entries for tappe without entry (today/past get entry, past get closed)"
  task backfill_entries: :environment do
    tappa_ids_with_entry = Entry.where(entryable_type: "Tappa").pluck(:entryable_id)

    tappe = Tappa.where("data_tappa IS NOT NULL AND data_tappa <= ?", Date.today)
                 .where.not(id: tappa_ids_with_entry)

    puts "Tappe da processare: #{tappe.count}"

    tappe.find_each do |tappa|
      entry = tappa.ensure_entry!
      if tappa.data_tappa < Date.today && entry.present?
        entry.close(user: tappa.user) unless entry.closed?
        print "x"
      else
        print "."
      end
    end

    puts "\nDone!"
  end
end
```

**Step 2: Run**

Run: `docker exec prova-app-1 bin/rails tappe:backfill_entries`

**Step 3: Commit**

```bash
git add lib/tasks/tappe_entries.rake
git commit -m "chore: backfill task for tappa entries"
```

---

### Task 7: Sezione "Prossime visite" nella scheda scuola

**Files:**
- Modify: `app/views/scuole/_container.html.erb` (or the entries turbo frame)

**Step 1: Identify where to add the section**

Check how `scuola_entries_path` renders — the tappe future section should go in the scuola container or in the entries frame, showing future tappe (no entry) for that scuola.

**Step 2: Add section**

After the entries turbo frames in `scuole/show.html.erb` or inside the container, add:

```erb
<% prossime_visite = @scuola.tappe.programmate.per_data.limit(10) %>
<% if prossime_visite.any? %>
  <div class="margin-block-start">
    <h3 class="divider divider--fade txt-medium font-weight-black">Prossime visite</h3>
    <ul class="flex flex-column gap-half">
      <% prossime_visite.each do |tappa| %>
        <li class="flex gap align-center txt-small">
          <span class="txt-subtle"><%= l tappa.data_tappa, format: :short %></span>
          <span><%= tappa.titolo.presence || tappa.giri.map(&:titolo).join(", ") %></span>
        </li>
      <% end %>
    </ul>
  </div>
<% end %>
```

**Step 3: Commit**

```bash
git add app/views/scuole/
git commit -m "feat: sezione prossime visite nella scheda scuola"
```

---

## Execution Order

1. Task 1 + 2: Tappa model changes (foundation)
2. Task 3 + 4: HasEntries + models (entries show in lists)
3. Task 5: Daily job
4. Task 6: Backfill (run once)
5. Task 7: Prossime visite UI

## Notes

- Type mismatch `entryable_id` (varchar) vs `tappe.id` (uuid): already handled via `.to_s` in Entryable concern and manual loading in Entry model. No joins needed.
- The `for_entryables` scope change is backward-compatible (third param defaults to `[]`).
- The backfill task is idempotent — safe to run multiple times.
- Views already support `tappa.entry` (preview, perma, stages partials).
