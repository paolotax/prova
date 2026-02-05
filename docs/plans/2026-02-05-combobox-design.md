# Design: Combobox Consolidation

**Data:** 2026-02-05
**Stato:** Completato (combobox_libro e entry streams), restano tax_select e cleanup preview

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

| Controller | Dominio | Stato |
|---|---|---|
| ~~`tax_combobox_causale_controller.js`~~ | Documenti | Sostituito con `documento_causale_controller.js` ✅ |
| `combobox_libro_controller.js` | Righe documento | Refactored a composizione ✅ |
| ~~`combobox_select_controller.js`~~ | Appunti/Adozioni | Eliminato (dead code) ✅ |

### Layer 4: Controller legacy (da tenere temporaneamente)

| Controller | Usato in | Note |
|---|---|---|
| `tax_select_controller.js` | `mandati/_mandati_select.html.erb`, `zone/_zone_select.html.erb` | Form con select native che fa submit su change |

## Decisioni prese

### 1. Generici: nessuna modifica necessaria
I controller `combobox` e `multi_selection_combobox` sono byte-per-byte identici a Fizzy. Le view dei filtri (`filters/settings/*`) usano gia il pattern Fizzy completo con `quick-filter`, `dialog`, `popup__list`, `popup__item`, `navigable-list`.

### 2. Business-specific: approccio composizione

**Completato:**
- `tax_combobox_causale_controller.js` → sostituito con `documento_causale_controller.js` (select nativo + fetch numero)
- `combobox_libro_controller.js` → refactored a composizione: URL e contesto clientable passati come Stimulus values, usa `event.detail.value` da `hw-combobox:selection`, dispatch `libro:loaded` event
- `combobox_select_controller.js` → eliminato (dead code, non referenziato)
- `_dialog_form.html.erb` → eliminato (dead code, `riga_form_frame` non piu' triggerato)

### 3. Dead code eliminato
9 file rimossi:
- `fancy_select_controller.js` (non referenziato)
- `tax_select_sort_controller.js` (non referenziato)
- `tax_select_causale_controller.js` (non referenziato)
- `tax_combobox_causale_controller.js` (sostituito da documento-causale)
- `combobox_select_controller.js` (non referenziato)
- `app/views/documenti/_form.html.erb` (legacy, non usata)
- `app/views/documenti/_edit_form.html.erb` (legacy, non usata)
- `app/views/documento_righe/_dialog_form.html.erb` (dead code)
- `app/views/appunti/display/preview/_columns.html.erb` (rimosso da preview, colonna gia' in header)

### 4. Date input: controller riutilizzabile
Creato `date_input_controller.js` per tutte le date dell'app:
- Text input per digitare in formato dd/mm/yyyy
- Click sull'icona calendario apre il picker nativo
- Hidden input manda ISO (yyyy-mm-dd) al server
- Applicato a: `_content.html.erb` (data_documento), `_gestione_dialog_content.html.erb` (consegnato_il, pagato_il)

### 5. Entry turbo streams: pattern generico per entryable
Estratto partial condiviso `entries/_replace_entryable_container.turbo_stream.erb` che usa `model_name` per risolvere dinamicamente partial e locals:

```erb
<% entryable = @entry.entryable %>
<%= turbo_stream.replace [ entryable, :container ],
    partial: "#{entryable.model_name.collection}/container",
    method: :morph,
    locals: { entryable.model_name.element.to_sym => entryable } %>
```

Funziona per qualsiasi entryable (Appunto, Documento, Tappa) senza if/elsif. Usato in tutti gli 8 template entry (closures, triages, not_nows, goldnesses).

### 6. Goldness per documenti
- Aggiunto pulsante goldness (evidenza) nelle left actions del documento container
- `documento_color` helper gestisce golden, closed, postponed
- Classe `golden-effect` su article quando documento e' golden
- Rimossa lista colonne dalla preview appunto (ridondante con badge header)

### 7. Bugfix: UUID quoting in sconti
`Sconto.sconto_per_libro` usava raw SQL `scontabile_id = #{entity.id}` senza quotes. Con clienti migrati a UUID, PostgreSQL falliva con `PG::SyntaxError`. Fix: `scontabile_id = '#{entity.id}'` nelle clausole ORDER BY.

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
├── date_input_controller.js                  # Nuovo ✅ (date tipizzabili)
├── documento_causale_controller.js           # Nuovo ✅ (composizione)
├── documento_editor_controller.js            # Refactored ✅ (form submit + targets)
├── combobox_libro_controller.js              # Refactored ✅ (composizione: values per URL e clientable)
└── tax_select_controller.js                  # Legacy (mandati/zone) — da convertire
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

## Prossimi passi

1. ~~**Refactoring `tax_combobox_causale`**~~ — FATTO: sostituito con `documento_causale_controller.js`
2. ~~**Convertire `combobox_libro_controller.js`**~~ — FATTO: composizione con Stimulus values
3. ~~**Eliminare `combobox_select_controller.js`**~~ — FATTO: dead code rimosso
4. ~~**Entry turbo streams per documenti**~~ — FATTO: partial generico `_replace_entryable_container`
5. ~~**Goldness per documenti**~~ — FATTO: pulsante + helper colore + golden-effect
6. **Convertire `tax_select_controller.js`** — al pattern Fizzy combobox nelle view mandati/zone
7. **Cleanup preview appunto** — verificare che `_columns.html.erb` non sia usato altrove e rimuoverlo
