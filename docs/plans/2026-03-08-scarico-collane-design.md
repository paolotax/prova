# Scarico Collane da Tappe

## Obiettivo

Tracciare la consegna in visione di gruppi di libri (collane) nelle scuole durante il giro.
Generare bolle numerate e datate. I libri in visione al ritiro diventano saggi o vengono fatturati (fase 2).

**Non è una Confezione** — la Confezione è un prodotto composto (più libri = 1 SKU vendibile).
La Collana è un gruppo di lavoro per la distribuzione visione nel giro.

## Modelli

### Collana
Gruppo libero di libri, cresce nel tempo man mano che arrivano novità.

```
Collana
  id          uuid (PK)
  nome        string        — es. "Novità primaria 2026"
  account_id  uuid          — AccountScoped
  user_id     bigint
  timestamps
```

### CollanaLibro
Join collana-libro con classi target predefinite.

```
CollanaLibro
  id            uuid (PK)
  collana_id    uuid
  libro_id      bigint
  classi_target string    — es. "1,2,3" o "4,5"
  position      integer   — positioned on: [:collana_id]
  account_id    uuid      — AccountScoped
  timestamps
```

### BollaVisione
Documento leggero, fuori dal ciclo fatture/saldo.

```
BollaVisione
  id            uuid (PK)
  numero        integer       — progressivo auto per account (con lock)
  data_bolla    date
  collana_id    uuid
  scuola_id     uuid
  tappa_id      uuid (optional)
  referente_id  uuid          — Persona con ruolo referente
  note          text
  account_id    uuid          — AccountScoped
  user_id       bigint
  timestamps
```

### BollaVisioneRiga
Riga della bolla, copiata da CollanaLibro ma modificabile.

```
BollaVisioneRiga
  id                uuid (PK)
  bolla_visione_id  uuid
  libro_id          bigint
  quantita          integer (default 1)
  classi_target     string    — copiato da CollanaLibro, modificabile
  position          integer   — positioned on: [:bolla_visione_id]
  account_id        uuid      — AccountScoped
  timestamps
```

### Persona (modifica esistente)
Aggiungere `referente` all'enum `ruolo`: `docente/dirigente/segretario/referente/altro`

## Flusso UX (mobile-first)

### Scarico dalla Tappa (sul campo)

1. Tappa show → pulsante "Scarica collana"
2. Dialog fullscreen mobile:
   - Selezione collana (combobox)
   - Referente (combobox persone scuola con ruolo referente, pre-selezionato se uno solo)
   - Data bolla (default oggi)
   - Conferma → crea bolla + copia tutte le righe dalla collana
3. Dopo creazione → show bolla con righe inline-editable:
   - Rimuovi righe non necessarie
   - Modifica quantità o classi target
   - Tutto con tap → edit → save

### Gestione Collane (da ufficio)

- CRUD `/collane` (index, new, create, edit, update, destroy)
- Crea collana: nome + aggiungi libri con combobox + classi target
- Aggiungi libri nel tempo (novità, libri vacanze, altri editori)

### Bolle nella Tappa show

- Sezione "Bolle visione" sotto il contenuto tappa
- Lista bolle emesse per quella scuola da quella tappa
- Link al PDF per ogni bolla

## Implementazione

### Routes

```ruby
resources :collane do
  resources :collana_libri, only: [:create, :destroy, :update]
end

resources :tappe do
  resources :bolle_visione, only: [:new, :create, :show]
end

resources :bolle_visione, only: [:index, :show] do
  resources :bolla_visione_righe, only: [:update, :destroy]
end
```

### Numerazione

```ruby
# before_create con lock per evitare race condition
before_create :assegna_numero

def assegna_numero
  self.numero = BollaVisione.where(account_id:).lock.maximum(:numero).to_i + 1
end
```

### Ordering

Usare `positioned` gem (come Tappa, ConfezioneRiga):
- `CollanaLibro`: `positioned on: [:collana_id], column: :position`
- `BollaVisioneRiga`: `positioned on: [:bolla_visione_id], column: :position`

### PDF (BollaVisionePdf)

- Header: dati azienda + scuola + referente
- Tabella: titolo libro, ISBN, quantità, classi destinazione
- Footer: numero bolla, data, totale copie

### Nessuna integrazione con

- Entry system (no kanban)
- Saldo / Consegnabile / Pagabile (non è documento fiscale)
- Broadcast (no real-time)

## Fase 2 (non ora)

- Invio email bolla a referente
- Ritiro: dalla bolla, segna riga per riga → saggio o fattura
- Tracking stato per riga (in visione / ritirato / saggiato / fatturato)
