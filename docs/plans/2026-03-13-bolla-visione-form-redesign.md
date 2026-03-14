# Redesign Form New Bolla Visione

## Obiettivo

Rivedere il form di creazione bolla visione per permettere di fare tutto senza navigare via:
scegliere collana, filtrare per target, cercare/creare persona con classi, generare bolla con righe filtrate.

## Flusso sequenziale

1. **Collana** — select `input input--select`, preselezionata dalla collana del giro (se presente)
2. **Target** — chip/toggle dei target unici dalla collana scelta. Filtrano:
   - quali libri entrano nella bolla (OR su tag comma-separated)
   - quali classi mostrare nel form persona (es. target "3" → classi con `anno_corso == "3"`)
3. **Persona** — riuso `_search_dialog` esistente adattato:
   - Combobox cerca persona esistente nella scuola
   - Form creazione nuova persona con toggle classi filtrate per target
   - Classi già assegnate alla persona restano toggolate
4. **Data** — automatica dalla tappa (hidden field)
5. **Note** — opzionale
6. **Create** → `crea_righe_da_collana!` filtra per target selezionati

## Modifiche necessarie

### Step 1: Fix stili select (input input--select)
- File: `app/views/bolle_visione/new.html.erb`
- Tutte le select devono avere `class: "input input--select"`

### Step 2: Controller new — preparare dati
- File: `app/controllers/bolle_visione_controller.rb`
- Precaricare collana dal giro della tappa (se presente)
- Caricare target unici dalla collana selezionata (endpoint JSON per cambio collana dinamico)
- Caricare classi della scuola filtrate per target
- Data automatica dalla tappa

### Step 3: Target chip/toggle
- File: `app/views/bolle_visione/new.html.erb`
- Mostrare target unici come chip selezionabili
- Stimulus controller per gestire selezione e filtro dinamico classi
- Quando cambia collana → aggiorna target disponibili

### Step 4: Form persona inline
- Riusare/adattare `scuole/persone/_search_dialog.html.erb`
- Toggle classi filtrate per target selezionato
- Classi già assegnate alla persona pre-selezionate

### Step 5: Logica create con filtro target
- File: `app/models/bolla_visione.rb`
- `crea_righe_da_collana!` accetta parametro `target_filter`
- Libro entra se almeno uno dei suoi tag (comma-separated) matcha un target selezionato
- Nessun target → tutti i libri (backward compatible)

### Step 6: Controller create — gestire persona e target
- File: `app/controllers/bolle_visione_controller.rb`
- Accettare `target_ids[]` params
- Creare persona se necessario (inline)
- Passare target a `crea_righe_da_collana!`

## File coinvolti

- `app/controllers/bolle_visione_controller.rb`
- `app/controllers/bolle_visione/persone_controller.rb`
- `app/models/bolla_visione.rb`
- `app/views/bolle_visione/new.html.erb`
- `app/views/scuole/persone/_search_dialog.html.erb` (riuso)
- `app/javascript/controllers/persona_search_controller.js`
- Nuovo Stimulus controller per target selection + filtro classi

## Dati

- `collana_libri.classi_target` diventa multi-valore comma-separated (es. "3,religione")
- Aggiornamento dati manuale (no migrazione)
