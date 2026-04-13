# Pianificabile Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Aggiungere un'azione rapida "Pianifica visita" (Oggi / Domani / Scegli giorno) sulla scheda di Scuola, Cliente, Classe, Persona, Appunto e Documento, che crea una `Tappa` per l'utente corrente via CRUD standard.

**Architecture:** Un concern `Pianificabile` fornisce `tappa_target` (default `self`) e `default_titolo_tappa`. I modelli "ponte" (Classe, Persona, Appunto, Documento) fanno override per delegare al destinatario visitabile. Un partial condiviso `tappe/_pianifica.html.erb` costruisce 3 bottoni che colpiscono `TappeController#create` e `#new` esistenti — zero route o action nuove.

**Tech Stack:** Rails 8.1, Minitest, Docker (`prova-app-1`). Design document: `docs/plans/2026-04-13-pianificabile-design.md`.

**Note di esecuzione:**
- Tutti i comandi Rails vanno eseguiti con `docker exec prova-app-1 ...`.
- Non esistono fixtures per `tappe` — i test le creano via `users(:one).tappe.build` o factory inline.
- Il progetto usa Minitest + fixtures (NO RSpec, NO FactoryBot).
- Commit atomici per task.

---

### Task 1: Creare il concern `Pianificabile` con test

**Files:**
- Create: `app/models/concerns/pianificabile.rb`
- Create: `test/models/concerns/pianificabile_test.rb`

**Step 1: Scrivere il test che fallisce**

`test/models/concerns/pianificabile_test.rb`:

```ruby
require "test_helper"

class PianificabileTest < ActiveSupport::TestCase
  class DummyTarget
    include Pianificabile
  end

  test "tappa_target returns self by default" do
    dummy = DummyTarget.new
    assert_equal dummy, dummy.tappa_target
  end

  test "default_titolo_tappa returns nil by default" do
    assert_nil DummyTarget.new.default_titolo_tappa
  end
end
```

**Step 2: Eseguire il test per vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/concerns/pianificabile_test.rb
```

Expected: FAIL — `uninitialized constant Pianificabile`.

**Step 3: Creare il concern**

`app/models/concerns/pianificabile.rb`:

```ruby
module Pianificabile
  extend ActiveSupport::Concern

  def tappa_target
    self
  end

  def default_titolo_tappa
    nil
  end
end
```

**Step 4: Rieseguire il test**

```bash
docker exec prova-app-1 bin/rails test test/models/concerns/pianificabile_test.rb
```

Expected: 2 runs, 0 failures.

**Step 5: Commit**

```bash
git add app/models/concerns/pianificabile.rb test/models/concerns/pianificabile_test.rb
git commit -m "feat(pianificabile): add concern with tappa_target default"
```

---

### Task 2: Includere `Pianificabile` in Scuola e Cliente (target diretti)

**Files:**
- Modify: `app/models/scuola.rb`
- Modify: `app/models/cliente.rb`
- Modify: `test/models/scuola_test.rb`

**Step 1: Aggiungere il test su Scuola**

Aggiungere a `test/models/scuola_test.rb`:

```ruby
test "scuola is its own tappa_target" do
  scuola = scuole(:one)
  assert_equal scuola, scuola.tappa_target
end
```

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n test_scuola_is_its_own_tappa_target
```

Expected: FAIL — `NoMethodError: undefined method 'tappa_target'`.

**Step 3: Includere il concern in entrambi i modelli**

In `app/models/scuola.rb`, aggiungere dopo gli altri `include`:

```ruby
include Pianificabile
```

In `app/models/cliente.rb`, stesso:

```ruby
include Pianificabile
```

**Step 4: Rieseguire il test**

```bash
docker exec prova-app-1 bin/rails test test/models/scuola_test.rb -n test_scuola_is_its_own_tappa_target
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/scuola.rb app/models/cliente.rb test/models/scuola_test.rb
git commit -m "feat(pianificabile): include in Scuola and Cliente"
```

---

### Task 3: Override `Pianificabile` in Classe

**Files:**
- Modify: `app/models/classe.rb`
- Create: `test/models/classe_test.rb`

**Step 1: Scrivere il test che fallisce**

`test/models/classe_test.rb`:

```ruby
require "test_helper"

class ClasseTest < ActiveSupport::TestCase
  test "tappa_target delegates to scuola" do
    classe = classi(:one)
    assert_equal classe.scuola, classe.tappa_target
  end

  test "default_titolo_tappa references the sezione" do
    classe = classi(:one)
    assert_match(/Classe/, classe.default_titolo_tappa)
  end
end
```

Se `classi(:one)` non ha una scuola nelle fixtures, aggiustare il fixture o creare inline l'associazione.

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/classe_test.rb
```

Expected: FAIL — metodo non definito.

**Step 3: Aggiungere include + override in `app/models/classe.rb`**

```ruby
include Pianificabile

def tappa_target
  scuola
end

def default_titolo_tappa
  "Classe #{sezione}".strip.presence
end
```

Verifica prima il nome esatto dell'attributo (potrebbe essere `sezione`, `nome`, `classe`): aprire `app/models/classe.rb` e adattare.

**Step 4: Rieseguire**

```bash
docker exec prova-app-1 bin/rails test test/models/classe_test.rb
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/classe.rb test/models/classe_test.rb
git commit -m "feat(pianificabile): classe delegates tappa_target to scuola"
```

---

### Task 4: Override `Pianificabile` in Persona (nullable)

**Files:**
- Modify: `app/models/persona.rb`
- Create: `test/models/persona_test.rb`

**Step 1: Scrivere i test**

`test/models/persona_test.rb`:

```ruby
require "test_helper"

class PersonaTest < ActiveSupport::TestCase
  test "tappa_target returns scuola when present" do
    persona = persone(:one)
    persona.update!(scuola: scuole(:one)) unless persona.scuola
    assert_equal persona.scuola, persona.tappa_target
  end

  test "tappa_target is nil without scuola" do
    persona = persone(:one)
    persona.update!(scuola: nil)
    assert_nil persona.tappa_target
  end
end
```

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/persona_test.rb
```

Expected: FAIL.

**Step 3: Aggiungere in `app/models/persona.rb`**

```ruby
include Pianificabile

def tappa_target
  scuola
end

def default_titolo_tappa
  [try(:ruolo), try(:nome_completo) || try(:nome)].compact.join(" ").presence
end
```

Verificare gli attributi reali (aprire `app/models/persona.rb` per vedere quali colonne esistono: `nome`, `cognome`, `ruolo`, `qualifica`…).

**Step 4: Rieseguire**

```bash
docker exec prova-app-1 bin/rails test test/models/persona_test.rb
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/persona.rb test/models/persona_test.rb
git commit -m "feat(pianificabile): persona delegates to scuola when present"
```

---

### Task 5: Override `Pianificabile` in Appunto

**Files:**
- Modify: `app/models/appunto.rb`
- Modify: `test/models/appunto_test.rb`

**Step 1: Aggiungere i test**

In `test/models/appunto_test.rb`:

```ruby
test "tappa_target is the appuntabile" do
  appunto = appunti(:one)
  assert_equal appunto.appuntabile, appunto.tappa_target
end

test "default_titolo_tappa contains date" do
  appunto = appunti(:one)
  assert_match Regexp.new(Regexp.escape(appunto.created_at.to_date.to_s(:short))),
               appunto.default_titolo_tappa.to_s
end
```

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/appunto_test.rb -n /tappa_target|default_titolo_tappa/
```

Expected: FAIL.

**Step 3: Modificare `app/models/appunto.rb`**

Aggiungere:

```ruby
include Pianificabile

def tappa_target
  appuntabile
end

def default_titolo_tappa
  "Appunto del #{I18n.l(created_at.to_date)}"
end
```

**Step 4: Rieseguire**

```bash
docker exec prova-app-1 bin/rails test test/models/appunto_test.rb -n /tappa_target|default_titolo_tappa/
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/appunto.rb test/models/appunto_test.rb
git commit -m "feat(pianificabile): appunto delegates to appuntabile"
```

---

### Task 6: Override `Pianificabile` in Documento (con esclusione NessunCliente)

**Files:**
- Modify: `app/models/documento.rb`
- Create: `test/models/documento_test.rb`

**Step 1: Scrivere i test**

`test/models/documento_test.rb`:

```ruby
require "test_helper"

class DocumentoTest < ActiveSupport::TestCase
  test "tappa_target is clientable when real" do
    documento = documenti(:one)
    assert_equal documento.clientable, documento.tappa_target
  end

  test "tappa_target is nil for NessunCliente" do
    documento = documenti(:one)
    documento.clientable = Domain::NessunCliente.new
    assert_nil documento.tappa_target
  end
end
```

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/models/documento_test.rb
```

Expected: FAIL.

**Step 3: Modificare `app/models/documento.rb`**

Aggiungere:

```ruby
include Pianificabile

def tappa_target
  return nil if clientable.is_a?(Domain::NessunCliente)
  clientable
end

def default_titolo_tappa
  [causale&.titolo, numero_documento].compact.join(" ").strip.presence
end
```

**Step 4: Rieseguire**

```bash
docker exec prova-app-1 bin/rails test test/models/documento_test.rb
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/models/documento.rb test/models/documento_test.rb
git commit -m "feat(pianificabile): documento delegates to clientable"
```

---

### Task 7: Partial condiviso `tappe/_pianifica`

**Files:**
- Create: `app/views/tappe/_pianifica.html.erb`

**Step 1: Creare il partial**

`app/views/tappe/_pianifica.html.erb`:

```erb
<%# locals: (source:) -%>

<% target = source.tappa_target %>
<% return unless target %>

<div class="btn-group" data-controller="" aria-label="Pianifica visita">
  <% [["Oggi", Date.current], ["Domani", Date.tomorrow]].each do |label, date| %>
    <%= button_to label, tappe_path, method: :post, params: {
          tappa: {
            tappable_type: target.class.name,
            tappable_id:   target.id,
            data_tappa:    date,
            titolo:        source.default_titolo_tappa
          }
        }, class: "btn", form: { data: { turbo: true } } %>
  <% end %>

  <%= link_to "Scegli giorno…", new_tappa_path(
        tappable_type: target.class.name,
        tappable_id:   target.id,
        source_titolo: source.default_titolo_tappa
      ), class: "btn" %>
</div>
```

**Step 2: Smoke test via rails runner (niente test view)**

```bash
docker exec prova-app-1 bin/rails runner 'puts ApplicationController.renderer.render(partial: "tappe/pianifica", locals: { source: Scuola.first })'
```

Expected: stampa HTML con tre bottoni; nessuna eccezione.

**Step 3: Commit**

```bash
git add app/views/tappe/_pianifica.html.erb
git commit -m "feat(pianificabile): shared partial for quick tappa actions"
```

---

### Task 8: Pre-compilare `titolo` in `TappeController#new`

**Files:**
- Modify: `app/controllers/tappe_controller.rb` (metodo `new`, righe 120–125)

**Step 1: Test di controller**

Aggiungere a `test/controllers/tappe_controller_test.rb` (se non esiste, crearlo):

```ruby
require "test_helper"

class TappeControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:one) }

  test "new pre-fills titolo from source_titolo" do
    scuola = scuole(:one)
    get new_tappa_path(tappable_type: "Scuola", tappable_id: scuola.id, source_titolo: "Visita speciale")
    assert_response :success
    assert_select 'textarea[name="tappa[titolo]"]', text: /Visita speciale/
  end
end
```

Verificare il metodo di login reale (potrebbe essere `sign_in_as`, `login_as`, o simili) — guardare un test di controller esistente.

**Step 2: Eseguire e vederlo fallire**

```bash
docker exec prova-app-1 bin/rails test test/controllers/tappe_controller_test.rb
```

Expected: FAIL — il titolo non è pre-compilato.

**Step 3: Modificare `TappeController#new`**

In `app/controllers/tappe_controller.rb`, metodo `new`:

```ruby
def new
  @tappable_type = params[:tappable_type] || "Scuola"
  @tappable_id   = params[:tappable_id]
  @data_tappa    = params[:data_tappa] || Date.today
  @tappa = current_user.tappe.build(
    tappable_id: @tappable_id,
    tappable_type: @tappable_type,
    data_tappa: @data_tappa,
    titolo: params[:source_titolo]
  )
end
```

**Step 4: Rieseguire**

```bash
docker exec prova-app-1 bin/rails test test/controllers/tappe_controller_test.rb
```

Expected: PASS.

**Step 5: Commit**

```bash
git add app/controllers/tappe_controller.rb test/controllers/tappe_controller_test.rb
git commit -m "feat(tappe): pre-fill titolo from source_titolo in new"
```

---

### Task 9: Montaggio partial su Appunto e Documento

**Files:**
- Modify: `app/views/appunti/container/_actions.html.erb`
- Modify: `app/views/documenti/container/_actions.html.erb`

**Step 1: Aggiungere il render in appunti**

Dopo il bottone "Stampa" in `app/views/appunti/container/_actions.html.erb`:

```erb
<%= render "tappe/pianifica", source: appunto %>
```

**Step 2: Aggiungere il render in documenti**

Aprire `app/views/documenti/container/_actions.html.erb`, individuare il bottone primario (stampa o simile), aggiungere sotto:

```erb
<%= render "tappe/pianifica", source: documento %>
```

**Step 3: Verifica manuale**

- `docker exec prova-app-1 bin/dev` non necessario — basta un render server-side:

```bash
docker exec prova-app-1 bin/rails runner 'puts ApplicationController.renderer.render(template: "appunti/show", assigns: { appunto: Appunto.first }) rescue puts $!.message'
```

Oppure, più realistico: navigare nel browser su una scheda appunto e verificare che i 3 bottoni compaiano e funzionino (creazione tappa "Oggi" e "Domani", "Scegli giorno…" apre la form).

**Step 4: Commit**

```bash
git add app/views/appunti/container/_actions.html.erb app/views/documenti/container/_actions.html.erb
git commit -m "feat(pianificabile): mount partial in appunto/documento actions"
```

---

### Task 10: Montaggio partial nelle sidebar di Scuola / Cliente / Classe / Persona

**Files:**
- Modify: `app/views/scuole/container/_prossime_visite.html.erb` (o file meta sidebar)
- Modify: `app/views/clienti/container/_container.html.erb` (o simili)
- Modify: `app/views/persone/_container.html.erb`
- Modify: `app/views/scuole/classi/_container.html.erb`

**Step 1: Esplorare il punto giusto per ogni scheda**

Non c'è `container/_actions` per questi modelli. Individuare per ciascuno un punto in testa alla sidebar dove abbia senso mostrare i 3 bottoni (tipicamente subito sopra `_prossime_visite.html.erb` per Scuola, o vicino al titolo della scheda).

Per ogni file, aggiungere:

```erb
<%= render "tappe/pianifica", source: <nome_locale> %>
```

dove `<nome_locale>` è `scuola` / `cliente` / `classe` / `persona` a seconda del contesto.

**Step 2: Verifica visiva nel browser**

Navigare a una scheda per ciascun tipo e verificare:
- I bottoni appaiono.
- "Oggi" crea una tappa con `data_tappa = oggi`.
- "Domani" → `data_tappa = domani`.
- "Scegli giorno…" apre la form `new` con il titolo pre-compilato.
- Dopo la creazione, "Prossime visite" si aggiorna (via broadcast Entry).

**Step 3: Test di integrazione minimo**

Aggiungere a `test/controllers/tappe_controller_test.rb`:

```ruby
test "creates tappa from scuola with date oggi" do
  scuola = scuole(:one)
  assert_difference -> { users(:one).tappe.count }, 1 do
    post tappe_path, params: {
      tappa: {
        tappable_type: "Scuola",
        tappable_id: scuola.id,
        data_tappa: Date.current,
        titolo: "Visita test"
      }
    }
  end
  tappa = users(:one).tappe.order(:created_at).last
  assert_equal scuola, tappa.tappable
  assert_equal Date.current, tappa.data_tappa
end
```

Eseguire:

```bash
docker exec prova-app-1 bin/rails test test/controllers/tappe_controller_test.rb
```

Expected: PASS.

**Step 4: Commit**

```bash
git add app/views/scuole app/views/clienti app/views/persone test/controllers/tappe_controller_test.rb
git commit -m "feat(pianificabile): mount partial in scuola/cliente/classe/persona sidebars"
```

---

### Task 11: Full test suite + manual smoke

**Step 1: Full test run**

```bash
docker exec prova-app-1 bin/rails test
```

Expected: 0 failures, 0 errors. Se qualche test preesistente fallisce, indagare — potrebbero esserci `assert_select` che contano bottoni in una scheda.

**Step 2: Smoke manuale nel browser**

- Scheda scuola → click "Oggi" → tappa creata, appare in "Prossime visite".
- Scheda appunto (il cui `appuntabile` è una scuola) → click "Domani" → tappa creata sulla scuola con titolo "Appunto del …".
- Scheda documento con `clientable` reale → click "Scegli giorno…" → form aperta con titolo pre-compilato; salvataggio ok.
- Scheda persona senza scuola → i bottoni NON appaiono.
- Scheda documento con `Domain::NessunCliente` → i bottoni NON appaiono.

**Step 3: Commit finale (se servono fix)**

Se durante lo smoke emergono aggiustamenti minori (testo, class CSS, placement), sistemarli e committare:

```bash
git commit -am "fix(pianificabile): smoke test adjustments"
```

---

## Note finali

- **Ordine obbligatorio**: Task 1 → 2 → 7 → 8 prima di montare i partial (Task 9-10).
- **Parallelizzabile**: i Task 3, 4, 5, 6 (ciascun modello-ponte) sono indipendenti tra loro una volta che Task 1 è fatto.
- **Rollback**: ciascun task è un commit singolo, tutti revertibili indipendentemente.
- **Out of scope**: scelta `giro` durante pianificazione rapida, descrizione libera, pianificazione da liste/tabelle.
