# Analisi Migrazione Prova → Pattern Fizzy

**Data:** 2026-01-29
**Ultimo Aggiornamento:** 2026-01-31
**Stato:** In corso - Sprint 4

## Executive Summary

L'applicazione **Prova** ha una buona base architetturale ma presenta diverse aree che deviano dai pattern **Fizzy** di riferimento. Questa analisi identifica le discrepanze e propone un piano di migrazione prioritizzato.

### Progressi Recenti (29-31 Gennaio)
- ✅ Entry system consolidato come pattern principale per state management
- ✅ CSS Fizzy creati (dialog.css, filters.css, inputs.css, popup.css)
- ✅ Scuola page migliorata con classi table, mie adozioni panel, entries lazy-loaded
- ✅ Tappe convertite a UUID con state records su Entry
- ✅ Appunto views consolidate, rimosso legacy stato system

---

## 1. FILTRI - Gap Significativo

### Stato Attuale Prova
- **TaxFilterFormComponent** come componente principale
- Multiple controller Stimulus custom (`tax_filters_controller`, `tax_combobox_*`)
- FilterProxy pattern per backend (buono)
- CSS custom → **✅ MIGRATO a filters.css**

### Pattern Fizzy
- **filter_settings_controller.js** con:
  - Debounce integrato
  - Tracking campi modificati vs default
  - Classe `.filters--has-filters-set`
  - POST con Turbo Streams
- **filter_dialog helper** per dropdown uniformi
- CSS variables per theming (`.filter__terms`, `.quick-filter`)

### Da Migrare

| Componente | Prova Attuale | Target Fizzy | Stato |
|------------|---------------|--------------|-------|
| Filter controller | `tax_filters_controller.js` | `filter_settings_controller.js` | ⏳ Pending |
| Combobox | `tax_combobox_*.js` (5 file) | `combobox_controller.js` + `multi_selection_combobox_controller.js` | ⏳ Pending |
| Dialog wrapper | `turbo_dialog` | `filter_dialog` helper | ⏳ Pending |
| CSS filtri | Custom Tailwind | `.filters`, `.quick-filter`, `.filter__terms` | ✅ Done |
| Search input | Vari pattern | `_terms.html.erb` con hotkey `[F]` | ⏳ Pending |

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
└── filters.css                       → ✅ CREATO
```

---

## 2. COMBOBOX/SELECT - Frammentazione Critica

### Stato Attuale Prova
- **11 controller diversi** per combobox/select ancora presenti:
  - `combobox_controller.js`
  - `multi_selection_combobox_controller.js`
  - `tax_combobox_causale_controller.js`
  - `tax_combobox_libro_controller.js`
  - `tax_combobox_select_controller.js`
  - `tax_select_causale_controller.js`
  - `tax_select_controller.js`
  - `tax_select_sort_controller.js`
  - `tax_checkbox_select_all_controller.js`
  - `fancy_select_controller.js`

### Pattern Fizzy
- **Solo 2 controller**:
  - `combobox_controller.js` (single selection)
  - `multi_selection_combobox_controller.js` (multi selection)
- Configurazione via `data-*-value` attributes

### Da Migrare

**Azione:** Consolidare gli 11 controller in 2, usando values per la configurazione.

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
- `tax_select_sort_controller.js` → Merge in `combobox_controller.js`
- `fancy_select_controller.js` → Valutare se necessario

---

## 3. DIALOGS/MODALS - Quasi Allineato

### Stato Attuale Prova
- `dialog_controller.js` - usa native `<dialog>` ✅
- `modal_controller.js` - legacy, da rimuovere
- `old_dialog_controller.js` - legacy, da rimuovere
- `openmodal_controller.js` - legacy, da rimuovere
- `dialog_manager_controller.js` - OK

### Pattern Fizzy
- `dialog_controller.js` con:
  - `modal` value per showModal vs show
  - `orient()` helper per positioning
  - `closeOnClickOutside` action
  - Lazy frame loading

### Da Migrare

| File | Azione | Stato |
|------|--------|-------|
| `modal_controller.js` | Eliminare | ⏳ Pending |
| `old_dialog_controller.js` | Eliminare | ⏳ Pending |
| `openmodal_controller.js` | Eliminare | ⏳ Pending |
| `nav_dialog_controller.js` | Valutare | ⏳ Pending |
| `dialog_controller.js` | Allineare | ⏳ Pending |
| `dialog.css` | Creare | ✅ Done |

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

| Componente | Stato |
|------------|-------|
| Form Controller extensions | ⏳ Pending |
| CSS Input Classes | ✅ Done (inputs.css) |
| auto_submit_form_with helper | ⏳ Pending |

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
⏳ **Pending** - Integrare in tutti i filter dialogs

---

## 6. BACKEND - Anti-Pattern Critici

### 6.1 Multi-Tenancy - Progressi

**Stato:** Parzialmente migliorato

| Metrica | Valore | Note |
|---------|--------|------|
| Modelli con `Current.account` | 6 | ✅ Migliorato |
| Modelli con `Current.user` | 14 | ⚠️ Da rivedere |
| Entry con AccountScoped | ✅ | Completo |
| Scuola page account-safe | ✅ | Link verificano account |

**Fix applicati:**
- ✅ Scuola card verifica `account_id == Current.account.id` prima di mostrare link
- ✅ Migration per correggere documenti con scuola di account diverso
- ✅ Entries controller scoped attraverso `Current.account`

### 6.2 State Pattern - ✅ COMPLETATO

**Problema risolto:** Entry è ora il pattern principale per state management

```ruby
# Entry concerns (NEW - pattern Fizzy)
class Entry < ApplicationRecord
  include Entry::Triageable
  include Entry::Eventable
  include Entry::Golden
  include Entry::Closeable
  include Entry::Postponable
end
```

**Legacy concerns ancora presenti ma deprecati:**
- `app/models/concerns/closeable.rb` → Da rimuovere dopo verifica
- `app/models/concerns/golden.rb` → Da rimuovere dopo verifica
- `app/models/concerns/postponable.rb` → Da rimuovere dopo verifica

**Modelli migrati a Entryable:**
- ✅ Appunto
- ✅ Documento
- ✅ Tappa

### 6.3 Service Objects Duplicati
⏳ **Pending** - Estrarre `BaseImporter`

### 6.4 SQL Injection Risk
⏳ **Pending** - Parametrizzare queries

---

## 7. ViewComponents - Allineamento

### Stato Attuale
- 13 ViewComponent generici
- `TaxFilterFormComponent` principale

### Raccomandazione
Mantenere ViewComponent per casi complessi, ma preferire:
- Helper methods per markup semplice
- Partials per sezioni riutilizzabili
- CSS classes per varianti visuali

---

## Piano di Migrazione Prioritizzato

### Sprint 1 - Sicurezza (Critico) ✅ PARZIALE
1. [x] Audit query con `Current.user` senza account scope - Parziale
2. [x] Fix link cross-account in scuola_card
3. [x] Migration per correggere documenti con account errato
4. [ ] Parametrizzare SQL in LibriImporter e FilterProxies

### Sprint 2 - Filtri Core ⏳ PENDING
5. [ ] Creare `filter_settings_controller.js` allineato a Fizzy
6. [ ] Consolidare 11 combobox controllers in 2
7. [ ] Aggiornare `filter_dialog` helper
8. [x] Creare `filters.css` con variabili Fizzy

### Sprint 3 - Dialogs & Forms ⏳ PENDING
9. [ ] Rimuovere `modal_controller.js` e `old_dialog_controller.js`
10. [x] Creare `dialog.css` con animazioni
11. [ ] Allineare `form_controller.js` con Fizzy
12. [x] Creare `inputs.css` con variabili

### Sprint 4 - Backend Cleanup ✅ IN CORSO
13. [x] Completare migrazione Appunto a Entry system
14. [x] Consolidare Closures su Entry
15. [x] Convertire Tappe a UUID
16. [ ] Estrarre `BaseImporter` per CSV importers
17. [ ] Rimuovere legacy concerns dopo verifica

### Sprint 5 - Polish ⏳ PENDING
18. [ ] Integrare `navigable-list` in tutti i dropdown
19. [ ] Aggiungere hotkeys globali
20. [ ] Review CSS per consistenza

---

## File Chiave per la Migrazione

### Creati ✅
```
app/assets/stylesheets/
├── filters.css     ✅
├── inputs.css      ✅
├── dialog.css      ✅
└── popup.css       ✅
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
├── tax_select_sort_controller.js
├── modal_controller.js
├── old_dialog_controller.js
└── openmodal_controller.js

app/models/concerns/ (dopo verifica non-uso)
├── closeable.rb (legacy - verificare)
├── golden.rb (legacy - verificare)
└── postponable.rb (legacy - verificare)
```

---

## Verifica

Per testare le modifiche:

1. **Scuola Page (NUOVO):**
   - Aprire una scuola
   - Verificare tabella classi raggruppata per combinazione
   - Verificare panel "Mie Adozioni" con link alle classi
   - Verificare entries panel lazy-loaded con card kanban

2. **Filtri Dashboard:**
   - Aprire `/dashboard`
   - Verificare che i filtri si aprano/chiudano correttamente
   - Verificare keyboard navigation (Arrow up/down, Enter, Escape)
   - Verificare hotkey `F` per focus su search

3. **Combobox:**
   - Testare single selection (es. ordinamento)
   - Testare multi-selection (es. discipline, editori)
   - Verificare che hidden fields siano popolati correttamente

4. **Forms:**
   - Testare auto-submit con debounce
   - Verificare validation messages
   - Testare submit to _top frame

5. **Test suite:**
   ```bash
   docker exec -it prova-app-1 bin/rails test
   docker exec -it prova-app-1 bin/rails test:system
   ```

---

## Prossimi Passi Consigliati

1. **Verifica legacy concerns** - Controllare se closeable.rb, golden.rb, postponable.rb sono ancora usati da modelli non-Entry
2. **Consolidamento combobox** - Priorità alta, 11 controller sono troppi
3. **Rimozione modal legacy** - Basso rischio, alto impatto pulizia
4. **Multi-tenancy audit** - Ridurre i 14 modelli con Current.user
