# Redesign Importazioni

## Obiettivo

Unificare il sistema importazioni: un solo controller, un solo flusso, processori asincroni, UI Fizzy.

Elimina il sistema duale (legacy session-based + moderno ImportRecord) a favore di un unico sistema basato su `ImportRecord` + `Imports::*Processor` + `ImportProcessJob`.

## Tipi di import

| Tipo | Sotto-tipi | File accettati | Processore |
|------|-----------|----------------|------------|
| Libri | standard, confezioni | CSV, Excel | `Imports::LibriProcessor`, `Imports::ConfezioniProcessor` |
| Clienti | — | CSV, Excel | `Imports::ClientiProcessor` |
| Documenti | xml, excel, pdf | XML, Excel, PDF | `Imports::DocumentiProcessor` (dispatch interno) |
| Insegnanti | — | PDF | `Imports::InsegnantiProcessor` (esiste) |

Export confezioni (XLSX) accessibile dalla pagina importazioni come azione dedicata.

## Backend

### Processori da creare

Tutti ereditano da `Imports::BaseProcessor`. Ricevono un `ImportRecord` con file e metadata.

**`Imports::LibriProcessor`** — logica da `LibriImporter#process!` e `#import_excel!`:
- Parse CSV/Excel
- Deduplica per `codice_isbn`
- Crea/aggiorna Libro, Editore, Categoria
- Traccia imported/updated/errors

**`Imports::ConfezioniProcessor`** — logica da `LibriImporter#import_confezioni_excel!`:
- Parse Excel (confezione_isbn, fascicolo_isbn, row_order)
- Crea associazioni ConfezioneRiga tra libri
- Utile per passare confezioni ad altri account

**`Imports::ClientiProcessor`** — logica da `ClientiImporter`:
- Parse CSV/Excel
- Deduplica per partita_iva o codice_fiscale
- Crea/aggiorna Cliente

**`Imports::DocumentiProcessor`** — già esiste, da arricchire:
- Sotto-tipo in `metadata[:format]`: `xml`, `excel`, `pdf`
- XML: parsing FatturaPA (da `DocumentiImporter#process!`)
- Excel: righe a documento esistente, `metadata[:documento_id]` (da `DocumentiImporter#import_excel!`)
- PDF: NdC parsing regex (da `DocumentiImporter#import_ndc_pdf!`)

### Flusso

```
Form/API → ImportsController#create → ImportRecord (pending) → ImportProcessJob
  → Imports::*Processor.new(import_record).call
  → Aggiorna status, contatori, error_messages
  → broadcasts_refreshes aggiorna la show page
```

### ImportRecord aggiornamenti

- Aggiungere `broadcasts_refreshes` al model
- Aggiornare enum `import_type` se serve (confezioni sotto-tipo di libri, gestito via metadata)
- `metadata` contiene: `format` (per documenti), `documento_id` (per excel righe), `scuola_id` (per insegnanti)

## Frontend

### Route

```ruby
resources :imports, only: [:new, :create, :show] do
  member do
    get :export
  end
end
```

Niente index separata. Il link nel menu punta a `new_import_path`.

### Pagina new (`/imports/new`)

- **Type selector**: `btn__group` con radio button (pattern Fizzy theme switcher)
  - Libri, Clienti, Documenti
  - Cambio tipo aggiorna turbo frame via `change->form#submit`
- **Sub-type selector** (dentro il frame, per libri e documenti):
  - Libri: standard / confezioni
  - Documenti: XML fattura / Excel righe / PDF NdC
- **File upload**: `.input--upload` (dashed border, pattern Fizzy) con `upload_preview_controller`
- **Help text**: colonne accettate, formato, logica deduplica
- **Export confezioni**: link/bottone in fondo al sotto-tipo confezioni
- **Importazioni recenti**: lista compatta (ultime 10) con stato e contatori, in fondo alla pagina

### Pagina show (`/imports/:id`)

- **Live update**: `turbo_stream_from @import_record` + `broadcasts_refreshes` (zero polling)
- **Stato**: `.import-status` con varianti `--success` / `--error` (pattern Fizzy)
  - Pending/processing: spinner + border dashed
  - Completed: check icon + contatori (importati, aggiornati)
  - Failed: X icon + contatori errori
- **Errori**: lista scrollabile, max 50 messaggi
- **Dettagli**: tipo, file, durata, timestamp
- **Azioni**: "Nuova importazione" (pre-seleziona stesso tipo), link alla risorsa

## API (futuro, per Scagnozz CLI)

```ruby
namespace :api do
  namespace :v1 do
    resources :imports, only: [:create, :show]
  end
end
```

Stessi processori, stessi ImportRecord. Il CLI:
1. `POST /api/v1/imports` con file + import_type + metadata → ritorna `import_id`
2. `GET /api/v1/imports/:id` → ritorna status + contatori + errori (polling)

## Cleanup

### File da eliminare

- `app/controllers/libri_importer_controller.rb`
- `app/controllers/clienti_importer_controller.rb`
- `app/controllers/documenti_importer_controller.rb`
- `app/services/libri_importer.rb`
- `app/services/clienti_importer.rb`
- `app/services/documenti_importer.rb`
- `app/views/libri_importer/` (tutta la directory)
- `app/views/clienti_importer/` (tutta la directory)
- `app/views/documenti_importer/` (tutta la directory)

### Route da eliminare

```ruby
resources :libri_importer
resource :clienti_importer
resources :documenti_importer
```

### File da creare

- `app/services/imports/libri_processor.rb`
- `app/services/imports/confezioni_processor.rb`
- `app/services/imports/clienti_processor.rb`

### File da aggiornare

- `app/services/imports/documenti_processor.rb` — aggiungere sotto-tipi XML/PDF
- `app/controllers/imports_controller.rb` — unico entry point, export action
- `app/models/import_record.rb` — broadcasts_refreshes
- `app/views/imports/new.html.erb` — redesign Fizzy
- `app/views/imports/show.html.erb` — live update
- `app/views/imports/forms/` — refactor partial
- `config/routes.rb` — semplificazione

## Ordine di implementazione

1. Creare i processori (libri, confezioni, clienti) con la logica dai legacy
2. Aggiornare documenti_processor con sotto-tipi
3. Aggiornare ImportRecord (broadcasts, metadata)
4. Rifare ImportsController come unico entry point
5. Rifare views con pattern Fizzy (new + show)
6. Aggiornare route, eliminare route legacy
7. Eliminare controller, service e views legacy
8. Test
