# Design: Combobox Consolidation

**Data:** 2026-02-05
**Stato:** Analisi completata, cleanup eseguito

## Risultato dell'analisi

L'analisi ha rivelato che la situazione e migliore del previsto: i controller generici sono gia identici a Fizzy e i filtri usano gia il pattern completo.

## Architettura attuale

### Layer 1: Controller generici (identici a Fizzy)

| Controller | Ruolo | Usato in |
|---|---|---|
| `combobox_controller.js` | Single-select con aria-checked, hidden field template, default value | Filtri, documenti form |
| `multi_selection_combobox_controller.js` | Multi-select con toggle, exclusive items, label con toSentence | Filtri (causali, editori, discipline, ecc.) |

Questi due controller gestiscono **solo la UI di selezione**: toggle aria-checked, aggiornamento label, hidden fields. Non fanno fetch, non hanno logica di dominio.

### Layer 2: Controller di supporto (identici a Fizzy)

| Controller | Ruolo |
|---|---|
| `dialog_controller.js` | Apre/chiude `<dialog>`, orient, click outside |
| `filter_controller.js` | Filtra items in un dropdown per testo digitato |
| `navigable_list_controller.js` | Navigazione keyboard (arrow up/down, enter) |
| `filter_settings_controller.js` | Traccia campi modificati, debounce submit |

Questi si combinano nella view: `data-controller="dialog filter combobox"` oppure `data-controller="dialog filter multi-selection-combobox"`.

### Layer 3: Controller business-specific (Prova-only)

| Controller | Dominio | Cosa fa |
|---|---|---|
| `tax_combobox_causale_controller.js` | Documenti | Su cambio causale → fetch `/documenti/nuovo_numero_documento` → aggiorna numero + clientable type |
| `tax_combobox_libro_controller.js` | Righe documento | Su selezione libro → fetch `/libri/:id/get_prezzo_e_sconto` → popola prezzo, sconto, focus quantita |
| `tax_combobox_select_controller.js` | Appunti/Adozioni | Su selezione scuola → fetch `/import_scuole/:id/combobox_classi` → Turbo Stream per classi |

Questi usano il **componente HW combobox** (non il combobox Fizzy) e aggiungono logica fetch specifica.

### Layer 4: Controller legacy (da tenere temporaneamente)

| Controller | Usato in | Note |
|---|---|---|
| `tax_select_controller.js` | `mandati/_mandati_select.html.erb`, `zone/_zone_select.html.erb` | Form con select native che fa submit su change |

## Decisioni prese

### 1. Generici: nessuna modifica necessaria
I controller `combobox` e `multi_selection_combobox` sono byte-per-byte identici a Fizzy. Le view dei filtri (`filters/settings/*`) usano gia il pattern Fizzy completo con `quick-filter`, `dialog`, `popup__list`, `popup__item`, `navigable-list`.

### 2. Business-specific: approccio composizione (futuro)
Quando servirà refactoring dei `tax_combobox_*`, l'approccio scelto e **composizione**:

```html
<!-- Esempio futuro: composizione di controller -->
<div data-controller="combobox documento-causale"
     data-action="combobox:change->documento-causale#fetchNumero">
  <!-- Il combobox gestisce la UI -->
  <!-- documento-causale gestisce il fetch del numero -->
</div>
```

Questo separa la UI (riutilizzabile) dalla logica di dominio (specifica).

**Non prioritario ora** perche i `tax_combobox_*` funzionano e usano un componente HW che piace.

### 3. Dead code eliminato
3 controller rimossi perche non referenziati in nessuna view:
- `fancy_select_controller.js`
- `tax_select_sort_controller.js`
- `tax_select_causale_controller.js`

### 4. Causale documento: da affrontare separatamente
La modifica della causale di un documento esistente e complessa (cambia numero, tipo clientable, ecc.) e richiede un design dedicato. Non in scope ora.

## Mappa dei file

### Controller Stimulus attuali (post-cleanup)

```
app/javascript/controllers/
├── combobox_controller.js                    # Fizzy ✅
├── multi_selection_combobox_controller.js     # Fizzy ✅
├── dialog_controller.js                      # Fizzy ✅
├── filter_controller.js                      # Fizzy ✅
├── filter_settings_controller.js             # Fizzy ✅
├── navigable_list_controller.js              # Fizzy ✅
├── tax_combobox_causale_controller.js        # Business (documenti)
├── tax_combobox_libro_controller.js          # Business (righe)
├── tax_combobox_select_controller.js         # Business (scuole→classi)
└── tax_select_controller.js                  # Legacy (mandati/zone)
```

### View pattern per i filtri (gia Fizzy)

```erb
<!-- Pattern standard filtro multi-selection -->
<div class="quick-filter"
     data-controller="dialog filter multi-selection-combobox"
     data-multi-selection-combobox-no-selection-label-value="Label...">

  <button class="btn input input--select" data-action="click->dialog#toggle:stop">
    <span data-multi-selection-combobox-target="label"></span>
  </button>

  <template data-multi-selection-combobox-target="hiddenFieldTemplate">
    <input type="hidden" name="field[]">
  </template>

  <%= filter_dialog "Label" do %>
    <ul class="popup__list" role="listbox">
      <li class="popup__item"
          data-multi-selection-combobox-target="item"
          data-multi-selection-combobox-value="val"
          data-multi-selection-combobox-label="Label"
          role="checkbox" aria-checked="false">
        <button class="btn popup__btn"
                data-action="dialog#close multi-selection-combobox#change filter-settings#change form#submit">
          <span>Label</span>
          <icon class="checked"></icon>
        </button>
      </li>
    </ul>
  <% end %>
</div>
```

## Prossimi passi possibili (non urgenti)

1. **Convertire `tax_select_controller.js`** al pattern Fizzy combobox nelle view mandati/zone
2. **Refactoring `tax_combobox_causale`** con approccio composizione quando si affronta la modifica causale
3. **Verificare `tax_combobox_select`** — usa `import_scuola_id` che potrebbe dover diventare `scuola_id` dopo la migrazione multi-tenancy
