# Analisi Migrazione Prova → Pattern Fizzy

**Data:** 2026-01-29
**Stato:** Analisi completata

## Executive Summary

L'applicazione **Prova** ha una buona base architetturale ma presenta diverse aree che deviano dai pattern **Fizzy** di riferimento. Questa analisi identifica le discrepanze e propone un piano di migrazione prioritizzato.

---

## 1. FILTRI - Gap Significativo

### Stato Attuale Prova
- **TaxFilterFormComponent** come componente principale
- Multiple controller Stimulus custom (`tax_filters_controller`, `tax_combobox_*`)
- FilterProxy pattern per backend (buono)
- CSS custom (non allineato a Fizzy)

### Pattern Fizzy
- **filter_settings_controller.js** con:
  - Debounce integrato
  - Tracking campi modificati vs default
  - Classe `.filters--has-filters-set`
  - POST con Turbo Streams
- **filter_dialog helper** per dropdown uniformi
- CSS variables per theming (`.filter__terms`, `.quick-filter`)

### Da Migrare

| Componente | Prova Attuale | Target Fizzy | Priorità |
|------------|---------------|--------------|----------|
| Filter controller | `tax_filters_controller.js` | `filter_settings_controller.js` | Alta |
| Combobox | `tax_combobox_*.js` (5 file) | `combobox_controller.js` + `multi_selection_combobox_controller.js` | Alta |
| Dialog wrapper | `turbo_dialog` | `filter_dialog` helper | Media |
| CSS filtri | Custom Tailwind | `.filters`, `.quick-filter`, `.filter__terms` | Media |
| Search input | Vari pattern | `_terms.html.erb` con hotkey `[F]` | Bassa |

### File da Modificare
```
app/javascript/controllers/
├── tax_filters_controller.js         → Sostituire con filter_settings_controller.js
├── tax_combobox_*.js (5 file)        → Consolidare in combobox_controller.js
├── filter_controller.js              → OK (già allineato)
└── multi_selection_combobox_controller.js → OK

app/views/filters/settings/
├── _discipline.html.erb              → Usare pattern multi-selection-combobox
├── _editori.html.erb                 → Usare pattern multi-selection-combobox
└── tutti i _*.html.erb               → Uniformare data-attributes

app/helpers/
└── filters_helper.rb                 → Allineare filter_dialog helper

app/assets/stylesheets/
└── Creare filters.css con variabili Fizzy
```

---

## 2. COMBOBOX/SELECT - Frammentazione Critica

### Stato Attuale Prova
- **8 controller diversi** per combobox/select:
  - `combobox_controller.js`
  - `multi_selection_combobox_controller.js`
  - `tax_combobox_causale_controller.js`
  - `tax_combobox_libro_controller.js`
  - `tax_combobox_select_controller.js`
  - `tax_select_causale_controller.js`
  - `tax_select_controller.js`
  - `fancy_select_controller.js`

### Pattern Fizzy
- **Solo 2 controller**:
  - `combobox_controller.js` (single selection)
  - `multi_selection_combobox_controller.js` (multi selection)
- Configurazione via `data-*-value` attributes

### Da Migrare

**Azione:** Consolidare gli 8 controller in 2, usando values per la configurazione.

```javascript
// Pattern target Fizzy
data-controller="combobox"
data-combobox-select-property-name-value="aria-checked"
data-combobox-default-value-value="latest"
data-combobox-default-label-value="Sort by..."
```

**File da eliminare/consolidare:**
- `tax_combobox_causale_controller.js` → Merge in `combobox_controller.js`
- `tax_combobox_libro_controller.js` → Merge in `combobox_controller.js`
- `tax_combobox_select_controller.js` → Merge in `combobox_controller.js`
- `tax_select_causale_controller.js` → Merge in `combobox_controller.js`
- `tax_select_controller.js` → Merge in `combobox_controller.js`
- `fancy_select_controller.js` → Valutare se necessario

---

## 3. DIALOGS/MODALS - Quasi Allineato

### Stato Attuale Prova
- `dialog_controller.js` - usa native `<dialog>` ✅
- `modal_controller.js` - legacy, da rimuovere
- `old_dialog_controller.js` - legacy, da rimuovere
- `dialog_manager_controller.js` - OK

### Pattern Fizzy
- `dialog_controller.js` con:
  - `modal` value per showModal vs show
  - `orient()` helper per positioning
  - `closeOnClickOutside` action
  - Lazy frame loading

### Da Migrare

| File | Azione | Note |
|------|--------|------|
| `modal_controller.js` | Eliminare | Sostituire usi con `dialog_controller` |
| `old_dialog_controller.js` | Eliminare | Legacy |
| `nav_dialog_controller.js` | Valutare | Potrebbe essere necessario |
| `dialog_controller.js` | Allineare | Aggiungere `orient()`, lazy loading |

**CSS da aggiungere:**
```css
/* dialog.css - animazioni Fizzy */
:is(.dialog) {
  opacity: 0;
  transform: scale(0.2);
  transition: var(--dialog-duration) allow-discrete;

  &[open] {
    opacity: 1;
    transform: scale(1);
  }
}
```

---

## 4. FORMS - Pattern Divergenti

### Stato Attuale Prova
- `TaxFilterFormComponent` come wrapper principale
- Tailwind inline classes
- Vari helper sparsi

### Pattern Fizzy
- `form_controller.js` con:
  - `debouncedSubmit`
  - `submitToTopTarget`
  - `preventEmptySubmit` validation
- CSS variables per input (`.input`, `.input--select`, `.input--transparent`)
- `auto_submit_form_with` helper

### Da Migrare

**1. Form Controller:**
```javascript
// Aggiungere a form_controller.js
submitToTopTarget(event) {
  this.element.setAttribute("data-turbo-frame", "_top")
  this.submit()
}

preventEmptySubmit(event) {
  // validation logic
}
```

**2. CSS Input Classes:**
```css
/* inputs.css */
.input {
  --input-background: transparent;
  --input-border-radius: 0.5em;
  --input-padding: 0.5em 0.8em;
  /* ... */
}

.input--select {
  --input-border-radius: 2em;
  appearance: none;
  background-image: var(--caret-icon);
}
```

**3. Helper:**
```ruby
# application_helper.rb
def auto_submit_form_with(**attributes, &)
  data = attributes.delete(:data) || {}
  data[:controller] = "auto-submit #{data[:controller]}".strip
  form_with **attributes, data: data, &
end
```

---

## 5. NAVIGABLE LIST & HOTKEYS - Mancante

### Stato Attuale Prova
- `navigable_list_controller.js` presente ma sottoutilizzato
- `hotkey_controller.js` presente

### Pattern Fizzy
- Navigazione keyboard completa in tutti i dropdown
- Hotkey `[F]` per focus su search
- Arrow navigation in liste

### Da Migrare

**Integrare in tutti i filter dialogs:**
```erb
<%= filter_dialog "Label" do %>
  <div data-controller="navigable-list"
       data-action="keydown->navigable-list#navigate">
    <!-- items con data-navigable-list-target="item" -->
  </div>
<% end %>
```

---

## 6. BACKEND - Anti-Pattern Critici

### 6.1 Multi-Tenancy Incompleto

**Problema:** Query senza account scoping
```ruby
# ANTI-PATTERN in libro.rb
has_many :user_adozioni, -> {
  Current.user.import_adozioni.da_acquistare.joins(:libro)
}
```

**Fix:** Sempre scopare attraverso `Current.account`
```ruby
has_many :user_adozioni, -> {
  Current.account.import_adozioni.da_acquistare.joins(:libro)
}
```

### 6.2 State Pattern Duplicato

**Problema:** Appunto ha sia legacy concerns (Closeable, Golden) che Entry-based system

**Fix:** Completare migrazione a Entry, rimuovere concerns legacy

### 6.3 Service Objects Duplicati

**Problema:** LibriImporter, ClientiImporter, DocumentiImporter duplicano CSV parsing

**Fix:** Estrarre `BaseImporter`
```ruby
class BaseImporter
  include ActiveModel::Model

  def import_csv(file)
    SmarterCSV.process(file) do |row|
      import_row(row)
    end
  end

  private
  def import_row(row)
    raise NotImplementedError
  end
end
```

### 6.4 SQL Injection Risk

**Problema:** Raw SQL con interpolazione in `libri_importer.rb:38`

**Fix:** Usare parameterized queries
```ruby
# INVECE DI:
WHERE users.id = #{Current.user.id}

# USARE:
.where(users: { id: Current.user.id })
```

---

## 7. ViewComponents - Allineamento

### Stato Attuale
- 13 ViewComponent generici
- `TaxFilterFormComponent` principale

### Pattern Fizzy
- Meno componenti, più helpers/partials
- CSS classes per varianti

### Raccomandazione
Mantenere ViewComponent per casi complessi, ma preferire:
- Helper methods per markup semplice
- Partials per sezioni riutilizzabili
- CSS classes per varianti visuali

---

## Piano di Migrazione Prioritizzato

### Sprint 1 - Sicurezza (Critico)
1. [ ] Audit query con `Current.user` senza account scope
2. [ ] Aggiungere `validates :account_id, presence: true` a tutti i modelli
3. [ ] Parametrizzare SQL in LibriImporter e FilterProxies

### Sprint 2 - Filtri Core
4. [ ] Creare `filter_settings_controller.js` allineato a Fizzy
5. [ ] Consolidare 8 combobox controllers in 2
6. [ ] Aggiornare `filter_dialog` helper
7. [ ] Creare `filters.css` con variabili Fizzy

### Sprint 3 - Dialogs & Forms
8. [ ] Rimuovere `modal_controller.js` e `old_dialog_controller.js`
9. [ ] Aggiungere animazioni dialog CSS
10. [ ] Allineare `form_controller.js` con Fizzy
11. [ ] Creare `inputs.css` con variabili

### Sprint 4 - Backend Cleanup
12. [ ] Completare migrazione Appunto a Entry system
13. [ ] Estrarre `BaseImporter` per CSV importers
14. [ ] Convertire `Scuola.stato` a enum

### Sprint 5 - Polish
15. [ ] Integrare `navigable-list` in tutti i dropdown
16. [ ] Aggiungere hotkeys globali
17. [ ] Review CSS per consistenza

---

## File Chiave per la Migrazione

### Da Creare
```
app/assets/stylesheets/
├── filters.css
├── inputs.css
├── dialog.css
└── popup.css
```

### Da Modificare
```
app/javascript/controllers/
├── filter_settings_controller.js (nuovo o allineare)
├── combobox_controller.js (estendere)
├── dialog_controller.js (allineare)
└── form_controller.js (estendere)

app/helpers/
└── filters_helper.rb (allineare filter_dialog)

app/views/filters/settings/
└── tutti i partial (uniformare data-attributes)
```

### Da Eliminare
```
app/javascript/controllers/
├── tax_combobox_causale_controller.js
├── tax_combobox_libro_controller.js
├── tax_combobox_select_controller.js
├── tax_select_causale_controller.js
├── tax_select_controller.js
├── modal_controller.js
└── old_dialog_controller.js

app/models/concerns/ (dopo migrazione Entry)
├── closeable.rb (legacy)
├── golden.rb (legacy)
├── postponable.rb (legacy)
└── altri state concerns legacy
```

---

## Verifica

Per testare le modifiche:

1. **Filtri Dashboard:**
   - Aprire `/dashboard`
   - Verificare che i filtri si aprano/chiudano correttamente
   - Verificare keyboard navigation (Arrow up/down, Enter, Escape)
   - Verificare hotkey `F` per focus su search

2. **Combobox:**
   - Testare single selection (es. ordinamento)
   - Testare multi-selection (es. discipline, editori)
   - Verificare che hidden fields siano popolati correttamente

3. **Forms:**
   - Testare auto-submit con debounce
   - Verificare validation messages
   - Testare submit to _top frame

4. **Test suite:**
   ```bash
   docker exec -it prova-app-1 bin/rails test
   docker exec -it prova-app-1 bin/rails test:system
   ```
