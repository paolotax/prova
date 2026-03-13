# Giro Wizard — Design Document

## Obiettivo

Creare un wizard a pagina intera per la creazione guidata dei giri. Il wizard automatizza la selezione delle scuole in base al tipo di giro e configura il template bolla (collana) associato. Il flusso attuale (crea giro → genera tappe manualmente) resta disponibile come alternativa semplice.

## Tipi di giro

| Tipo | Selezione scuole | Collana |
|------|-----------------|---------|
| Kit adozioni | Scuole con `Adozione.where(mia: true)` dell'utente | No |
| Consegna collane | Tutte le scuole `where.missing(:scartata)` | Sì, obbligatoria |
| Ritiro collane | Scuole con `BollaVisione` della collana selezionata | Sì, obbligatoria |
| Consegne generiche | Manuale (checkbox gerarchici come ora) | No |
| Visite commerciali | Manuale o tutte meno scartate | No |

## Modello dati

### Nuovo modello: `Scartata`

Record di stato su Scuola (pattern Closure/Goldness). Una scuola scartata viene esclusa dai giri collane e visite. Non influenza i kit adozioni.

```ruby
# scartate table
- id: uuid (PK)
- scuola_id: uuid (FK, not null)
- user_id: bigint (FK, not null)
- account_id: uuid (FK, not null)
- created_at, updated_at
# unique index su (scuola_id, user_id)
```

Concern `Scartabile` su Scuola:

```ruby
module Scartabile
  extend ActiveSupport::Concern
  included do
    has_one :scartata, dependent: :destroy
    scope :non_scartate, -> { where.missing(:scartata) }
  end

  def scartata?
    scartata.present?
  end
end
```

### Nuovi campi su `Giro`

```ruby
add_column :giri, :tipo_giro, :string
add_column :giri, :collana_id, :uuid
```

- `tipo_giro`: enum string — `kit_adozioni`, `collane`, `ritiro_collane`, `consegne`, `visite`
- `collana_id`: FK opzionale → `Collana` (presente solo per giri collane/ritiro)
- `belongs_to :collana, optional: true` su Giro

### Nessun template bolla

La collana con i suoi `CollanaLibro` è già il template. `BollaVisione#crea_righe_da_collana!` copia i libri dalla collana. Le bolle si generano tappa per tappa quando si è pronti, non dal wizard.

## Flusso wizard (4 step)

### Step 1 — Tipo giro

Grid di 5 card cliccabili con icona e descrizione:
- Kit adozioni
- Consegna collane
- Ritiro collane
- Consegne
- Visite

Click seleziona e avanza.

### Step 2 — Info giro

Form con:
- **Titolo**: precompilato dal tipo (es. "Collane Primavera 2026"), editabile
- **Colore**: color picker (già esistente)
- **Date inizio/fine**: opzionali
- **Collana**: combobox per selezionare collana — visibile solo per tipo collane/ritiro

### Step 3 — Scuole

Lista scuole generata automaticamente dal tipo:
- *Kit adozioni*: `Scuola.joins(classi: :adozioni).where(adozioni: { mia: true })`
- *Collane*: `Scuola.non_scartate` (dell'utente)
- *Ritiro*: `Scuola.joins(:bolle_visione).where(bolle_visione: { collana_id: giro.collana_id })`
- *Consegne/Visite*: selezione manuale con checkbox gerarchici

Ogni scuola ha un toggle on/off. Header con contatore ("42 scuole selezionate") e "Seleziona tutte / Deseleziona tutte".

### Step 4 — Riepilogo e crea

Card riassuntiva: tipo, titolo, collana, colore, numero scuole. Bottone "Crea giro" → genera Giro + Tappe → redirect a pagina giro.

## Implementazione tecnica

### Controller: `Giri::WizardController`

```ruby
# GET  /giri/wizard/new          → step 1 (tipo)
# GET  /giri/wizard/info         → step 2 (info)
# GET  /giri/wizard/scuole       → step 3 (scuole)
# GET  /giri/wizard/riepilogo    → step 4 (conferma)
# POST /giri/wizard              → genera tutto e redirect
```

Dati tra step via hidden fields in un form che avvolge tutto.

### Generazione tappe

Per tutti i tipi, ogni tappa:
- `tappable: scuola`
- `user: Current.user`
- `account: Current.account`
- `data_tappa: nil` (da programmare)
- Collegata al giro via `TappaGiro`

### Frontend

- Layout wizard full-screen: sidebar con step indicator + area principale
- Turbo Frames per caricare ogni step
- Stimulus controller `wizard_controller.js` leggero per navigazione
- CSS da pattern Fizzy esistenti

### Cosa NON fa il wizard

- Non crea bolle/documenti — si generano tappa per tappa quando serve
- Non assegna date alle tappe — si programmano dopo nella pagina giro
- Non gestisce la chiusura dei ritiri — processo manuale sul posto
- Non gestisce lo spezzettamento bolle su più referenti — si fa nella bolla visione
