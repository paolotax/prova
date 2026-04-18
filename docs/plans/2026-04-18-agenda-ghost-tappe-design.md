# Agenda ghost-tappe nella show giro

**Data**: 2026-04-18
**Branch**: `feature/multi-tenancy`

## Obiettivo

Nella show di un giro, dentro `<div class="agenda-calendar">`, mostrare anche le tappe di **altri giri dell'utente** pianificate negli stessi giorni, in stile "fantasma" (desaturate, cliccabili ma non draggabili). Serve per:

- Evitare di doppiare scuole già pianificate altrove
- Vedere la densità reale dell'agenda mentre si pianifica il giro corrente
- Saltare velocemente alla tappa altrui via click

Scope minimo: **sola visualizzazione**. Nessuna modifica alla logica di drag/drop o generazione.

## Scelte

### Dati
Nel `GiriController#show`, accanto a `@tappe_per_giorno`, calcolare:

```ruby
window = @giro.settimane.first.first..@giro.settimane.last.last
@altre_tappe_per_giorno = current_user.tappe
  .where(data_tappa: window)
  .where.not(id: @giro.tappe.select(:id))
  .includes(:tappable, :giri)
  .group_by(&:data_tappa)
```

- Finestra = prima settimana → ultima settimana di `@giro.settimane`
- Esclusione per `id` tappa (non per tappable): se una tappa è già anche nel giro corrente via `tappa_giri`, è già nelle proprie e non va duplicata
- Skip quando `@giro.settimane` è vuoto

### Vista
- `giri/show.html.erb` passa `altre_tappe_per_giorno` al partial `agenda/week`
- `agenda/_week.html.erb` renderizza i ghost in un **contenitore separato** `.agenda-week__tappe-ghosts`, fratello di `.agenda-week__tappe`, fuori dal `tax-sortable` → zero interferenze con drop/ordering
- Riuso `tappe/_tappa_compact.html.erb` con nuovo local `ghost: false` (default). Se `ghost: true`:
  - Aggiunge classe modifier `tappa-compact--ghost`
  - Rimuove `draggable` e `data-tax-sortable-update-url`
  - Wrappa in `link_to tappa_path(tappa)` per navigazione

### CSS (`agenda-calendar.css`)
```css
.agenda-week__tappe-ghosts {
  display: flex;
  flex-direction: column;
  gap: 0.25em;
  margin-block-start: 0.5em;
  padding-block-start: 0.5em;
  border-block-start: 1px dashed var(--color-ink-lighter);
}

.tappa-compact--ghost { opacity: 0.55; filter: grayscale(0.6); cursor: pointer; }
.tappa-compact--ghost:hover { opacity: 0.85; filter: grayscale(0.2); }
```

### Test
- `test/controllers/giri_controller_test.rb`: `@altre_tappe_per_giorno` contiene le tappe altrui nella finestra, esclude quelle del giro corrente e quelle fuori finestra.

## Fuori scope

- Drag-merge (drop di una tappa sopra una ghost → merge nel giro ghost)
- Collisioni in `Giro#genera_tappe_per` (fase 2)
- Ghost nelle altre viste (agenda settimanale, planner, kanban)
