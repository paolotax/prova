# Email Pattern Docenti — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Auto-suggest teacher email addresses based on the school district's (direzione) email pattern and domain.

**Architecture:** Two new string columns on `scuole` (`email_pattern`, `email_dominio`). A method on Scuola generates the email from nome/cognome. Two Stimulus controllers: one for preview on scuola form, one for auto-populate on persona form. Pattern and domain data passed via DOM attributes — no server calls for generation.

**Tech Stack:** Rails migration, Ruby model method, Stimulus JS controllers, Fizzy CSS

---

### Task 1: Migration — add email_pattern and email_dominio to scuole

**Files:**
- Create: `db/migrate/XXXXXX_add_email_pattern_to_scuole.rb`

**Step 1: Generate the migration**

```bash
docker exec prova-app-1 bin/rails generate migration AddEmailPatternToScuole email_pattern:string email_dominio:string
```

**Step 2: Run the migration**

```bash
docker exec prova-app-1 bin/rails db:migrate
```

Expected: Migration runs, `scuole` table has `email_pattern` and `email_dominio` columns.

**Step 3: Commit**

```bash
git add db/migrate/*add_email_pattern* db/schema.rb
git commit -m "feat: add email_pattern and email_dominio columns to scuole"
```

---

### Task 2: Model — genera_email_docente method on Scuola

**Files:**
- Modify: `app/models/scuola.rb`
- Test: `test/models/scuola_test.rb`

**Step 1: Write the failing test**

Add to `test/models/scuola_test.rb`:

```ruby
class ScuolaEmailPatternTest < ActiveSupport::TestCase
  setup do
    @scuola = scuole(:direzione_kennedy)  # we'll create this fixture
  end

  test "genera_email_docente with nome.cognome pattern" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "mario.rossi@ickennedy.istruzione.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with n.cognome pattern" do
    @scuola.update!(email_pattern: "n.cognome", email_dominio: "icdavinci.edu.it")
    assert_equal "m.rossi@icdavinci.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with cognome.nome pattern" do
    @scuola.update!(email_pattern: "cognome.nome", email_dominio: "icmanzoni.edu.it")
    assert_equal "rossi.mario@icmanzoni.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with nomecognome pattern" do
    @scuola.update!(email_pattern: "nomecognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "mariorossi@ickennedy.istruzione.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente with cognomenome pattern" do
    @scuola.update!(email_pattern: "cognomenome", email_dominio: "icdavinci.edu.it")
    assert_equal "rossimario@icdavinci.edu.it", @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente returns nil without pattern or dominio" do
    @scuola.update!(email_pattern: nil, email_dominio: nil)
    assert_nil @scuola.genera_email_docente("Mario", "Rossi")
  end

  test "genera_email_docente handles accented names" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "nicolo.deandre@ickennedy.istruzione.it", @scuola.genera_email_docente("Nicolò", "De André")
  end

  test "genera_email_docente handles spaces in names" do
    @scuola.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    assert_equal "maria.deluca@ickennedy.istruzione.it", @scuola.genera_email_docente("Maria", "De Luca")
  end

  test "plesso delegates to direzione for email pattern" do
    direzione = scuole(:direzione_kennedy)
    direzione.update!(email_pattern: "nome.cognome", email_dominio: "ickennedy.istruzione.it")
    plesso = scuole(:plesso_kennedy)
    plesso.update!(direzione: direzione, email_pattern: nil, email_dominio: nil)
    assert_equal "mario.rossi@ickennedy.istruzione.it", plesso.genera_email_docente("Mario", "Rossi")
  end
end
```

**Note on fixtures:** Use existing fixtures if available, or add minimal ones. Check `test/fixtures/scuole.yml` for existing fixture names and adapt test setup accordingly.

**Step 2: Run test to verify it fails**

```bash
docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n /genera_email/
```

Expected: FAIL — `genera_email_docente` not defined.

**Step 3: Implement the method on Scuola**

Add to `app/models/scuola.rb` (before `private`):

```ruby
EMAIL_PATTERNS = {
  "nome.cognome" => :nome_punto_cognome,
  "n.cognome" => :iniziale_punto_cognome,
  "cognome.nome" => :cognome_punto_nome,
  "nomecognome" => :nome_cognome,
  "cognomenome" => :cognome_nome
}.freeze

def genera_email_docente(nome, cognome)
  pattern = email_pattern.presence || direzione&.email_pattern
  dominio = email_dominio.presence || direzione&.email_dominio
  return nil if pattern.blank? || dominio.blank?

  nome_norm = normalize_email_part(nome)
  cognome_norm = normalize_email_part(cognome)
  return nil if nome_norm.blank? || cognome_norm.blank?

  local_part = case pattern
  when "nome.cognome" then "#{nome_norm}.#{cognome_norm}"
  when "n.cognome" then "#{nome_norm[0]}.#{cognome_norm}"
  when "cognome.nome" then "#{cognome_norm}.#{nome_norm}"
  when "nomecognome" then "#{nome_norm}#{cognome_norm}"
  when "cognomenome" then "#{cognome_norm}#{nome_norm}"
  else
    pattern # custom pattern — future use
  end

  "#{local_part}@#{dominio}"
end

private

def normalize_email_part(str)
  return "" if str.blank?
  str.unicode_normalize(:nfkd)
     .gsub(/[\u0300-\u036f]/, "") # remove accents
     .gsub(/[^a-zA-Z]/, "")       # remove non-alpha (spaces, apostrophes, etc.)
     .downcase
end
```

**Step 4: Run tests to verify they pass**

```bash
docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n /genera_email/
```

Expected: All tests PASS.

**Step 5: Commit**

```bash
git add app/models/scuola.rb test/models/scuola_test.rb test/fixtures/scuole.yml
git commit -m "feat: add genera_email_docente method to Scuola"
```

---

### Task 3: Scuola form — email pattern section

**Files:**
- Modify: `app/views/scuole/_form.html.erb`
- Modify: `app/controllers/scuole_controller.rb` (add to `scuola_params`)

**Step 1: Add email_pattern and email_dominio to scuola_params**

In `app/controllers/scuole_controller.rb`, add `:email_pattern, :email_dominio` to the permit list in `scuola_params`.

**Step 2: Add "Email docenti" section to the scuola form**

In `app/views/scuole/_form.html.erb`, after the "Contatti" section (after line 104), add:

```erb
<!-- Email docenti -->
<strong class="divider txt-large">Email docenti</strong>

<div class="flex flex-column gap"
     data-controller="email-pattern"
     data-email-pattern-patterns-value='<%= Scuola::EMAIL_PATTERNS.keys.to_json %>'>
  <div class="form-grid">
    <div class="form-field">
      <%= f.label :email_pattern, "Formato", class: "form-label" %>
      <%= f.select :email_pattern,
          options_for_select(
            [["—", ""]] +
            Scuola::EMAIL_PATTERNS.keys.map { |p| [p, p] } +
            [["Altro...", "custom"]],
            scuola.email_pattern.presence&.then { |p| Scuola::EMAIL_PATTERNS.key?(p) ? p : "custom" }
          ),
          {},
          class: "input input--select",
          data: { email_pattern_target: "select", action: "email-pattern#update" } %>
    </div>

    <div class="form-field">
      <%= f.label :email_dominio, "Dominio", class: "form-label" %>
      <%= f.text_field :email_dominio, class: "input",
          placeholder: "es. ickennedy.istruzione.it",
          data: { email_pattern_target: "dominio", action: "input->email-pattern#update" } %>
    </div>
  </div>

  <div class="form-field" data-email-pattern-target="customField" style="<%= 'display:none' unless scuola.email_pattern.present? && !Scuola::EMAIL_PATTERNS.key?(scuola.email_pattern) %>">
    <%= f.label :email_pattern, "Pattern personalizzato", class: "form-label" %>
    <%= f.text_field :email_pattern, class: "input",
        placeholder: "es. cognome.n",
        value: (scuola.email_pattern unless Scuola::EMAIL_PATTERNS.key?(scuola.email_pattern)),
        data: { email_pattern_target: "customInput", action: "input->email-pattern#update" },
        name: "" %>
  </div>

  <p class="txt-small txt-muted" data-email-pattern-target="preview"></p>
</div>
```

**Step 3: Verify form renders**

Visit a scuola edit page in the browser and confirm the "Email docenti" section renders with the dropdown and domain field.

**Step 4: Commit**

```bash
git add app/views/scuole/_form.html.erb app/controllers/scuole_controller.rb
git commit -m "feat: add email pattern fields to scuola form"
```

---

### Task 4: Stimulus controller — email-pattern (preview on scuola form)

**Files:**
- Create: `app/javascript/controllers/email_pattern_controller.js`

**Step 1: Create the Stimulus controller**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "dominio", "preview", "customField", "customInput"]
  static values = { patterns: Array }

  connect() {
    this.update()
  }

  update() {
    this.toggleCustomField()
    this.updatePreview()
  }

  toggleCustomField() {
    if (!this.hasCustomFieldTarget) return
    const isCustom = this.selectTarget.value === "custom"
    this.customFieldTarget.style.display = isCustom ? "" : "none"

    if (isCustom) {
      this.customInputTarget.name = "scuola[email_pattern]"
      this.selectTarget.name = ""
    } else {
      this.selectTarget.name = "scuola[email_pattern]"
      this.customInputTarget.name = ""
    }
  }

  updatePreview() {
    const pattern = this.selectTarget.value === "custom"
      ? this.customInputTarget.value
      : this.selectTarget.value
    const dominio = this.dominioTarget.value

    if (!pattern || !dominio) {
      this.previewTarget.textContent = ""
      return
    }

    const email = this.generateEmail("mario", "rossi", pattern, dominio)
    this.previewTarget.textContent = email ? `es. ${email}` : ""
  }

  generateEmail(nome, cognome, pattern, dominio) {
    let local
    switch (pattern) {
      case "nome.cognome": local = `${nome}.${cognome}`; break
      case "n.cognome": local = `${nome[0]}.${cognome}`; break
      case "cognome.nome": local = `${cognome}.${nome}`; break
      case "nomecognome": local = `${nome}${cognome}`; break
      case "cognomenome": local = `${cognome}${nome}`; break
      default: return null
    }
    return `${local}@${dominio}`
  }
}
```

**Step 2: Verify in browser**

Visit a scuola edit page. Select a pattern and type a domain. The preview should update live showing "es. mario.rossi@dominio.it".

**Step 3: Commit**

```bash
git add app/javascript/controllers/email_pattern_controller.js
git commit -m "feat: add email-pattern Stimulus controller for scuola form preview"
```

---

### Task 5: Stimulus controller — email-suggest (auto-populate on persona form)

**Files:**
- Create: `app/javascript/controllers/email_suggest_controller.js`
- Modify: `app/views/persone/_edit_form.html.erb`

**Step 1: Create the Stimulus controller**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nome", "cognome", "email"]
  static values = { pattern: String, dominio: String }

  suggest() {
    const nome = this.nomeTarget.value.trim()
    const cognome = this.cognomeTarget.value.trim()
    const pattern = this.patternValue
    const dominio = this.dominioValue

    if (!nome || !cognome || !pattern || !dominio) return
    if (this.manuallyEdited) return

    const email = this.generateEmail(
      this.normalize(nome),
      this.normalize(cognome),
      pattern,
      dominio
    )
    if (email) this.emailTarget.value = email
  }

  markManual() {
    this.manuallyEdited = true
  }

  clearManual() {
    // Reset when nome/cognome changes so suggestion kicks in again
    this.manuallyEdited = false
    this.suggest()
  }

  normalize(str) {
    return str
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-zA-Z]/g, "")
      .toLowerCase()
  }

  generateEmail(nome, cognome, pattern, dominio) {
    let local
    switch (pattern) {
      case "nome.cognome": local = `${nome}.${cognome}`; break
      case "n.cognome": local = `${nome[0]}.${cognome}`; break
      case "cognome.nome": local = `${cognome}.${nome}`; break
      case "nomecognome": local = `${nome}${cognome}`; break
      case "cognomenome": local = `${cognome}${nome}`; break
      default: return null
    }
    return `${local}@${dominio}`
  }
}
```

**Step 2: Modify the persona edit form**

In `app/views/persone/_edit_form.html.erb`, wrap the form in the email-suggest controller and wire up targets.

The controller wrapper needs to be added to the form tag, and data attributes for pattern/dominio need to come from the persona's scuola (or its direzione):

```erb
<%
  email_scuola = persona.scuola&.then { |s| s.email_pattern.present? ? s : s.direzione } || persona.scuola&.direzione
  email_pattern = email_scuola&.email_pattern
  email_dominio = email_scuola&.email_dominio
%>
```

Add `email-suggest` to the form's data-controller, and add data values:

```
data: { controller: "form email-suggest",
        email_suggest_pattern_value: email_pattern,
        email_suggest_dominio_value: email_dominio }
```

Add targets to nome, cognome, and email fields:

- cognome field: `data: { email_suggest_target: "cognome", action: "input->email-suggest#clearManual" }`
- nome field: `data: { email_suggest_target: "nome", action: "input->email-suggest#clearManual" }`
- email field: `data: { email_suggest_target: "email", action: "input->email-suggest#markManual" }`

**Step 3: Verify in browser**

Edit a persona whose scuola/direzione has email_pattern and dominio configured. Type nome and cognome — the email field should auto-populate.

**Step 4: Commit**

```bash
git add app/javascript/controllers/email_suggest_controller.js app/views/persone/_edit_form.html.erb
git commit -m "feat: add email-suggest controller for auto-populating persona email"
```

---

### Task 6: Update model annotations

**Step 1: Run annotate**

```bash
docker exec prova-app-1 bundle exec annotaterb models
```

**Step 2: Commit**

```bash
git add app/models/scuola.rb
git commit -m "chore: update scuola model annotations"
```
