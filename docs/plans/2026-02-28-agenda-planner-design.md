# Agenda Planner — Pannello drag-and-drop per pianificazione tappe

## Problema

Pianificare le tappe dei giri (propaganda, consegna collane, ritiri, ecc.) è macchinoso. Oggi bisogna andare nella pagina del singolo giro, usare il Kanban a 3 colonne, selezionare una data e creare le tappe. Non c'è visione settimanale durante la pianificazione.

## Soluzione

Aggiungere un **pannello tappe non programmate** sotto al calendario settimanale dell'agenda. Il pannello mostra tutte le tappe senza `data_tappa` raggruppate per area e direzione. L'utente seleziona le scuole (plessi) e le trascina nei giorni del calendario, oppure usa bottoni giorno su mobile.

## Flusso utente

1. Crea un giro (es. "Consegna collane 2026") → genera tappe per tutte le scuole elementari, senza data
2. Apre l'agenda → il pannello sotto mostra le tappe non programmate
3. Seleziona i plessi di un'area (es. "Roma Nord" → IC Trionfale, 4 plessi)
4. Li trascina sul martedì → le tappe ricevono `data_tappa`, compaiono nel calendario
5. Continua con le scuole di "Roma Sud" sul mercoledì, ecc.

## Struttura UI

### Calendario settimanale (già esistente)

Ogni cella giorno mostra mini card con nome plesso + pallino colorato per giro:

```
┌─ Mar 4 (6) ──────────┐
│ Via Trionfale 85  🟡  │
│ Via Monte Zebio   🟡  │
│ Via Nomentana 56  🔵  │
│ Via Val Padana    🔵  │
│ Piazza Sempione   🔵  │
│ Via Cipro 2       🟡  │
└───────────────────────┘
```

Le card sono draggable tra giorni (drag esistente via `tappa_date_controller`).

### Pannello tappe non programmate (nuovo)

Drawer sotto al calendario, toggle apertura/chiusura.

**Header:** "Da programmare" + conteggio + filtro giro (combobox) + toggle chiudi.

**Contenuto raggruppato per area → direzione → plessi:**

```
▼ Roma Nord (18)
  IC Via Trionfale (4 plessi)
    □ Plesso Via Trionfale 85       collane
    □ Plesso Via Monte Zebio 15     collane
    □ Plesso Via Cipro 2            collane
    □ Plesso Via degli Ammiragli    collane
  IC Montesacro (3 plessi)
    □ Plesso Via Nomentana 56       collane | ritiri
    □ Plesso Via Val Padana         collane
    □ Plesso Piazza Sempione        collane

▼ Roma Sud (14)
  IC Spinaceto (2 plessi)
    □ Plesso Via Pontina            collane
    □ Plesso Via Laurentina         collane
  ...

▼ Senza area (3)
  ...
```

Ogni riga: checkbox + nome plesso + badge giro (colorati). Click sulla direzione seleziona tutti i suoi plessi.

### Selezione batch e drop

- Checkbox per selezionare singoli plessi o intera direzione
- Drag: trascinare una tappa selezionata porta con sé tutte le selezionate
- Al drop su un giorno: PATCH batch per ogni tappa con `data_tappa` + `position`
- Turbo Stream: rimuove le tappe dal pannello, le aggiunge al giorno del calendario

### Fallback mobile

Quando ci sono tappe selezionate, compare una barra azione fissa in basso con i giorni della settimana visibile come bottoni. Tap sul giorno → PATCH batch.

## Routes CRUD

Nessuna azione custom. Tutto CRUD standard.

| Azione | Metodo | Route | Controller | Cosa fa |
|--------|--------|-------|------------|---------|
| Genera tappe giro | POST | `/giri/:giro_id/tappe` | `Giri::TappeController#create` | Crea una tappa per ogni scuola del giro, senza `data_tappa` |
| Lista non programmate | GET | `/tappe?filter=da_programmare` | `TappeController#index` | Pannello agenda (turbo frame) |
| Sposta su giorno | PATCH | `/tappe/:id` | `TappeController#update` | Aggiorna `data_tappa` + `position` |
| Rimuovi da giorno | PATCH | `/tappe/:id` | `TappeController#update` | Setta `data_tappa = nil` (torna nel pannello) |

### Routes

```ruby
resources :giri do
  resources :tappe, only: [:create, :index], controller: "giri/tappe"
end
```

### Giri::TappeController#create

Genera le tappe per le scuole del giro. Logica:
- Prende le scuole filtrate dal giro (condizioni + escluse)
- Crea una Tappa per ogni scuola (plesso) senza `data_tappa`
- Associa la tappa al giro via `TappaGiro`
- Non crea duplicati (skip se tappa già esiste per quella scuola+giro)

## Stimulus controllers

### Estendere `tappa_date_controller` (esistente)

Già gestisce il drag singolo scuola → giorno. Estendere per:
- Accettare drop dal pannello planner (stesso formato `data-school-id`)
- Supportare drop multiplo: leggere lista tappe selezionate da `agenda-planner` controller
- Al drop batch: PATCH sequenziale per ogni tappa, poi Turbo Stream aggiorna tutto

### Nuovo: `agenda-planner` controller

Responsabilità:
- Toggle apertura/chiusura pannello
- Gestione selezione batch (checkbox singole + per direzione)
- Mantiene Set di tappa IDs selezionati
- Al dragstart di una tappa selezionata: serializza tutti gli IDs selezionati nel dataTransfer
- Filtro per giro (combobox cambia turbo frame src)
- Collassa/espande sezioni area
- Barra azione mobile con bottoni giorno

## Generazione tappe — logica

Quando si creano le tappe di un giro, il livello è la **singola scuola** (plesso), non la direzione. In una giornata l'utente potrebbe visitare 2 plessi di una direzione e 4 di un'altra.

```ruby
# Giri::TappeController#create
def create
  giro = current_user.giri.find(params[:giro_id])
  schools = giro.filter_schools(scuole_for_giro(giro))

  schools.each do |scuola|
    next if giro.tappe.exists?(tappable: scuola)

    tappa = current_user.tappe.create!(
      tappable: scuola,
      account: Current.account,
      data_tappa: nil
    )
    tappa.tappa_giri.create!(giro: giro)
  end
end
```

## Files da creare/modificare

### Nuovo
- `app/controllers/giri/tappe_controller.rb` — genera tappe per giro
- `app/views/agenda/_planner.html.erb` — pannello tappe non programmate
- `app/views/agenda/_planner_area.html.erb` — sezione area con direzioni e plessi
- `app/javascript/controllers/agenda_planner_controller.js` — selezione batch, toggle, filtro

### Modificare
- `app/views/agenda/index.html.erb` — aggiungere turbo frame per il pannello
- `app/javascript/controllers/tappa_date_controller.js` — supporto drop multiplo
- `config/routes.rb` — nested route `giri/tappe`
- `app/views/tappe/_tappa_compact.html.erb` — aggiungere pallino colore giro

## Out of scope

- Refactor del modello Giro (condizioni, esclusioni) — resta com'è
- Vista Kanban dei giri — resta per chi la preferisce
- Riordino tappe dentro un giorno — già gestito da `tax-sortable`
- PDF e mappa giornaliera — restano invariati
- Creazione/editing giri — resta invariato

## Ordine implementazione

1. **Route + controller** `Giri::TappeController#create` — genera tappe senza data
2. **Pannello planner** — partial `_planner.html.erb` con raggruppamento area/direzione/plesso
3. **Integrazione agenda** — turbo frame nel calendario per caricare il pannello
4. **Stimulus `agenda-planner`** — selezione batch, toggle, collassa aree
5. **Estendere drag** — drop multiplo dal pannello ai giorni
6. **Barra mobile** — bottoni giorno come fallback per touch
7. **Pallino giro** — colore sul `_tappa_compact` nel calendario
