# Refactor Ritiri + Bolle Visione — Design

**Branch:** `feature/ritiro-bolle-visione`
**Data:** 2026-05-09
**Stato:** approvato per implementazione

## Goal

Ristrutturare i controller del flusso "ritiro bolle visione" e "composizione bolle visione" per:

1. eliminare custom action travestite da CRUD (`RitiriController#rientro`/`#riapri`)
2. raggruppare i controller correlati in due namespace coerenti (`Ritiri::` e `BolleVisione::`)
3. rimuovere duplicazioni (`set_scuola` / `set_bolla_visione` ripetuti)
4. trasformare il service `Ritiro::CreaDocumento` in un PORO unico `Ritiro` (entità di dominio invece di service object verbale)

## Non-goals

- Niente nuova tabella DB `ritiri`. Il `Ritiro` resta concettuale (PORO), non persistente.
- Niente refactor di altri spazi del codice (Documento, Causale, Scuola, ecc).
- Nessuna modifica di schema oltre alla migration già presente nel branch (`remove_documento_riga_from_bolla_visione_righe`).

## Design

### 1. Struttura controller

```
app/controllers/
├── bolle_visione_controller.rb              # index, show, new, create, destroy, rigenera
├── bolle_visione/
│   ├── base_controller.rb                   # auth + set_bolla_visione
│   ├── righe_controller.rb                  # create/update/destroy righe (composizione)
│   └── persone_controller.rb                # già esistente, eredita da Base
├── ritiri_controller.rb                     # show (pagina ritiro per scuola)
└── ritiri/
    ├── base_controller.rb                   # auth + set_scuola
    ├── righe_controller.rb                  # update esito (rientro/riapri unificati)
    ├── documenti_controller.rb              # create Documento da righe selezionate
    └── bolle_controller.rb                  # create N bolle da collane in fase ritiro
```

**Responsabilità:**

- **`BolleVisione::*`** — fase di composizione: la bolla viene creata sotto una tappa, le righe popolate da `crea_righe_da_collana!`, l'utente edita quantità/classi/consegna.
- **`Ritiri::*`** — fase di lavorazione: l'utente arriva in scuola, vede tutte le bolle aperte raggruppate, seleziona righe, le rientra o genera documenti (saggio, vendita, mancante).

La stessa `BollaVisioneRiga` ha due controller perché ha due fasi di vita: composizione e lavorazione. Un controller solo confonderebbe le responsabilità.

### 2. PORO `Ritiro`

`app/models/ritiro.rb` — entità di dominio, non service object verbale.

```ruby
class Ritiro
  CAUSALE_TO_ESITO = {
    "Scarico saggi" => :in_saggio,
    "TD01"          => :venduto_fattura,
    "Ordine Scuola" => :venduto_corrispettivi,
    "Mancante"      => :mancante
  }.freeze

  attr_reader :scuola

  def initialize(scuola)
    @scuola = scuola
  end

  # --- vista ----------------------------------------------------------------

  def bolle
    @bolle ||= scuola.bolle_visione
      .joins(:bolla_visione_righe)
      .where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
      .includes(:collana)
      .distinct.ordered
  end

  def righe(bolla)            = righe_per_bolla[bolla]
  def gruppo_per(libro, coll) = gruppo_lookup[[coll, libro]]
  def empty?                  = bolle.empty?

  # --- comandi --------------------------------------------------------------

  def crea_documento(righe:, causale:, clientable:, data:)
    raise ArgumentError, "causale è obbligatoria" if causale.nil?

    Documento.transaction do
      documento = Current.account.documenti.create!(
        causale: causale, clientable: clientable,
        data_documento: data, numero_documento: prossimo_numero(causale),
        user: Current.user
      )
      righe.each_with_index { |riga, i| processa_riga(riga, documento, i, causale) }
      documento
    end
  end

  private

  def visibili_sql
    "bolla_visione_righe.processato_at IS NULL OR bolla_visione_righe.esito = ?"
  end

  def righe_per_bolla
    @righe_per_bolla ||= bolle.each_with_object({}) do |bv, h|
      h[bv] = bv.bolla_visione_righe.where(visibili_sql, BollaVisioneRiga.esiti[:rientrato])
        .includes(:libro).order(:position)
    end
  end

  def gruppo_lookup
    @gruppo_lookup ||= CollanaLibro.where(collana_id: bolle.map(&:collana_id).uniq)
      .pluck(:collana_id, :libro_id, :gruppo)
      .each_with_object({}) { |(c, l, g), h| h[[c, l]] = g }
  end

  def prossimo_numero(causale)
    (Current.account.documenti.where(causale: causale).maximum(:numero_documento) || 0) + 1
  end

  def processa_riga(bv_riga, documento, idx, causale)
    riga = Riga.create!(libro: bv_riga.libro, quantita: bv_riga.quantita,
                        prezzo_cents: bv_riga.libro.prezzo_in_cents)
    documento.documento_righe.create!(riga: riga, posizione: idx)
    bv_riga.update!(esito: CAUSALE_TO_ESITO.fetch(causale.causale), processato_at: Time.current)
  end
end
```

**Conseguenze:**

- `app/services/ritiro/crea_documento.rb` viene **cancellato**.
- `test/services/ritiro/crea_documento_test.rb` migra in `test/models/ritiro_test.rb` (mantiene tutti i case esistenti).
- Niente più `module Ritiro` in services → nessun conflitto namespace.
- `applica_split_fascicoli` resta nel controller `Ritiri::DocumentiController` (legge params, non è dominio puro).

### 3. Routes

```ruby
# Composizione bolla — sotto tappa (new/create)
resources :tappe, only: [] do
  resources :bolle_visione, only: %i[new create]
end

# Lifecycle bolla stand-alone
resources :bolle_visione, only: %i[index show destroy] do
  member { post :rigenera }
  scope module: :bolle_visione do
    resources :righe,    only: %i[create update destroy]
    resource  :persone,  only: %i[create update]
  end
end

# Ritiro per scuola
resources :scuole, only: [] do
  resource :ritiro, only: :show
  scope :ritiro, module: :ritiri, as: :ritiro do
    resources :righe,     only: :update
    resources :documenti, only: :create
    resources :bolle,     only: :create
  end
end
```

**Mapping URL e path helpers:**

| Oggi | Domani |
|---|---|
| `bolla_visione_bolla_visione_riga_path(bv, riga)` | `bolla_visione_riga_path(bv, riga)` |
| `scuola_ritiro_riga_rientro_path(scuola, id)` (PATCH) | `scuola_ritiro_riga_path(scuola, id)` (PATCH) con `{esito: "rientrato"}` |
| `scuola_ritiro_riga_riapri_path(scuola, id)` (PATCH) | stesso URL sopra con `{esito: ""}` |
| `scuola_ritiro_documenti_path(scuola)` | invariato |
| `scuola_ritiro_bolle_da_collane_path(scuola)` | `scuola_ritiro_bolle_path(scuola)` |
| `bolla_visione_rigenera_path(bv)` | `rigenera_bolla_visione_path(bv)` |

**Note:**

- `scope module: :ritiri` produce URL piatte `/scuole/:scuola_id/ritiro/righe/:id` con controller namespaced.
- `rientro`/`riapri` unificati in `update` con `params[:esito]` (stringa enum o vuota).
- `rigenera` come member action invece di route custom standalone.
- Verificare che l'inflection `bolla` ↔ `bolle` sia presente in `config/initializers/inflections.rb` (probabilmente già, dato che `bolle_visione` funziona).

### 4. Viste e partial

I partial restano dove sono (convenzione `to_partial_path` di Rails è basata sul **modello**, non sul controller):

```
app/views/
├── bolla_visione_righe/
│   └── _bolla_visione_riga.html.erb     # invariato — partial del modello
├── bolle_visione/
│   ├── index.html.erb
│   ├── show.html.erb
│   └── new.html.erb
└── ritiri/
    ├── show.html.erb                    # legge @ritiro invece di @bolle/@righe_per_bolla/@gruppo
    ├── _lista.html.erb
    ├── _riga.html.erb                   # PATCH unica con :esito
    ├── _bulk_bar.html.erb
    ├── _crea_bolle_da_collane.html.erb  # path: bolle_da_collane → bolle
    └── _dialog_fascicoli.html.erb
```

**Cambi nei view:**

- `ritiri/show.html.erb` — `@bolle.each` → `@ritiro.bolle.each`; `@righe_per_bolla[bolla]` → `@ritiro.righe(bolla)`; `@gruppo_per_libro_e_collana[[c, l]]` → `@ritiro.gruppo_per(l, c)`.
- `ritiri/_riga.html.erb` — un solo `button_to` con `params: { esito: "rientrato" | "" }` calcolato in base allo stato corrente.
- `ritiri/_crea_bolle_da_collane.html.erb` — path helper rinominato.

**File esterni da aggiornare** (path helpers): `tappe/show.html.erb`, `scuole/_container.html.erb`, `giri/wizard/new.html.erb`, `app/javascript/controllers/wizard_controller.js`, `app/controllers/giri/wizard_controller.rb`, `bolla_visione_righe/_bolla_visione_riga.html.erb`. Verificare via grep finale che nessun riferimento legacy resti.

### 5. Test

```
test/
├── controllers/
│   ├── bolle_visione_controller_test.rb              # invariato
│   ├── bolle_visione/
│   │   └── righe_controller_test.rb                  # rinomina
│   ├── ritiri_controller_test.rb                     # snellito (usa Ritiro PORO)
│   └── ritiri/
│       ├── righe_controller_test.rb                  # nuovo
│       ├── documenti_controller_test.rb              # rinomina
│       └── bolle_controller_test.rb                  # nuovo
├── models/
│   ├── bolla_visione_riga_test.rb                    # invariato
│   └── ritiro_test.rb                                # nuovo (assorbe ex crea_documento_test)
```

**Coverage `Ritiro` PORO:**

- vista: bolle visibili includono righe rientrate, escludono altre processate; `gruppo_per` coerente con `CollanaLibro`; `empty?`.
- comandi: `crea_documento` happy path; `causale: nil` → `ArgumentError`; transaction rollback su errore di una riga; `prossimo_numero`.

**Coverage controller (essenziali, non duplicare il PORO):**

- `Ritiri::RigheController#update`: `{esito: "rientrato"}` → riga rientrata + redirect; `{esito: ""}` → riga riaperta.
- `Ritiri::DocumentiController#create`: happy path + `ArgumentError` gestito + `applica_split_fascicoli` (logica residua nel controller).
- `Ritiri::BolleController#create`: crea N bolle, redirect, validazione `collana_ids` vuoto.

**Fixture:** invariate.

### 6. Step di esecuzione

Ogni step deve lasciare i test verdi e essere committabile.

**Step 1 — PORO `Ritiro` con vista (no breaking)**
- crea `app/models/ritiro.rb` con metodi vista (`bolle`, `righe`, `gruppo_per`, `empty?`)
- aggiorna `RitiriController#show` per usare `@ritiro = Ritiro.new(@scuola)`
- aggiorna `ritiri/show.html.erb` per leggere via `@ritiro`
- crea `test/models/ritiro_test.rb` per la vista

**Step 2 — Sposta `crea_documento` nel PORO**
- aggiungi `Ritiro#crea_documento`
- aggiorna `RitiriDocumentiController#create` per chiamare `Ritiro.new(@scuola).crea_documento(...)`
- migra i test da `test/services/ritiro/crea_documento_test.rb` a `test/models/ritiro_test.rb`
- cancella `app/services/ritiro/crea_documento.rb` e directory

**Step 3 — Namespace `Ritiri::` per i controller documenti+bolle**
- crea `Ritiri::BaseController` (auth + `set_scuola`)
- sposta `RitiriDocumentiController` → `Ritiri::DocumentiController`
- sposta `BolleVisioneDaCollaneController` → `Ritiri::BolleController`
- aggiorna routes + path helpers nei view
- rinomina test files

**Step 4 — Unifica `rientro`/`riapri` in `Ritiri::RigheController#update`**
- crea `Ritiri::RigheController#update` con `params[:esito]`
- routes: `resources :righe, only: :update` dentro lo scope ritiro
- aggiorna `ritiri/_riga.html.erb` (un solo button con `params:`)
- rimuovi `rientro`/`riapri` da `RitiriController` (resta solo `show`)

**Step 5 — Namespace `BolleVisione::` per le righe**
- crea `BolleVisione::BaseController` (auth + `set_bolla_visione`)
- sposta `BollaVisioneRigheController` → `BolleVisione::RigheController`
- `BolleVisione::PersoneController` esistente eredita da `Base`
- aggiorna routes + path helpers (`bolla_visione_riga_path`)
- rinomina test files

**Step 6 — Cleanup**
- `rigenera` come member action su `bolle_visione`
- grep finale per riferimenti legacy
- verifica/aggiunge inflection `bolla` ↔ `bolle`
- esecuzione completa test suite

## Risk e mitigazioni

| Rischio | Mitigazione |
|---|---|
| Path helpers rotti in view non identificati | grep finale al cleanup; CI con system test |
| Conflitto namespace `Ritiro` (modulo vs classe) | risolto cancellando `app/services/ritiro/` allo Step 2 |
| Inflection `bolla`/`bolle` mancante | check esplicito allo Step 3 prima di `bolles_path` |
| Stimulus `bulk_bar_controller` con URL hardcoded | step 4 rilegge i path da `data-*` se non già fatto |
| Bookmark utenti su `bolle_da_collane` | flow interno, accettabile rinominare |

## Open questions

Nessuna — tutte le scelte di design sono confermate.
