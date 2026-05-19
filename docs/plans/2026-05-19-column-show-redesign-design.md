# Column Show — Redesign sezione entries + bulk actions

**Data**: 2026-05-19
**Pagina**: `/<account_id>/columns/<column_id>` (`ColumnsController#show`)
**Scope**: solo la sezione 1 della show (lista entries). Sezione 2 (Volumi) e sezione 3 (Adozioni) restano invariate.

## Problema

Oggi la sezione 1 mostra, per ogni cliente/scuola, un panel con una grid di card. Verticalmente è lunga, occupa molto spazio e non offre bulk actions. Su una colonna piena si scorre molto e si agisce una entry alla volta.

## Obiettivo

1. Layout "tabellare" cliente → entries inline, le entries vanno a capo dentro la cella del cliente (wrap).
2. Riusare il pattern bulk actions esistente per entries (selezione → barra azioni).

## Decisioni

### Layout

- Una "riga" per destinatario (Scuola, Persona, Cliente, o `nil` per "Senza destinatario").
- Due celle in CSS Grid: `minmax(180px, 220px) 1fr`.
  - Cella sx: denominazione, comune, badge col conteggio.
  - Cella dx: `cards cards--in-context` con `flex-wrap: wrap`. Le card mantengono il partial esistente `entries/_entry`.
- Niente `<table>` HTML: layout via CSS Grid, contenuto non tabellare.
- Niente scroll-x: overflow gestito con wrap.

### Modalità "in-context"

Le card mostrate dentro un contesto cliente usano la classe contenitore `cards--in-context` (CSS già definito in `app/assets/stylesheets/utilities.css` e `card-columns.css`). Effetti automatici:

- `.card__hide-in-context` nasconde denominazione/comune ridondanti.
- `.card__show-in-context` mostra varianti compatte (es. solo anno+sezione per `Classe`).

Niente nuove varianti di card: il pattern esiste già ed è usato in `entries/_open_list`, `entries/_closed_list`, `agenda/show`, `scuole/container/_prossime_visite`, `documenti/container/_documenti_collegabili`.

### Bulk actions

- Wrapper `<div data-controller="bulk-actions" data-action="click->bulk-actions#toggleCard">` **attorno all'intera sezione 1**, non per riga. La selezione è quindi globale alla colonna: si possono mischiare entries di clienti diversi in un'unica azione bulk.
- Riuso integrale di `entries/bulk_bar/_bar.html.erb`, identico a `entries/_open_list` e `entries/_closed_list`. Pulsanti: Stampa, Gestione (dialog), Stato (sposta in colonna / Completa / Da gestire), Elimina, Tutti.
- Le card (`_appunto`, `_documento`, `_tappa`) hanno già `card__checkbox` con `data-action="change->bulk-actions#count"`.

Endpoint già presenti, **nessuno da creare**:

- `POST entries/prints` → `Entries::PrintsController`
- `GET entries/bulk_gestione` → `Entries::BulkGestioneController` (apre dialog → render `documenti/bulk_gestione/show`)
- `POST entries/bulk_stati` → `Entries::BulkStatiController` (`azione: triage|completa|da_gestire`)
- `POST entries/deletions` → `Entries::DeletionsController`

### Nota — "Sposta in colonna corrente"

La barra `entries/bulk_bar/_bar` itera su `current_account.columns.ordered`, quindi include anche la colonna corrente come destinazione. È un no-op innocuo lato server. Non vale la pena complicare la barra con un'opzione per nasconderla: YAGNI, si rivede se infastidisce nell'uso reale.

## File toccati

| File | Tipo | Motivo |
|------|------|--------|
| `app/views/columns/show.html.erb` | modifica | sostituisce solo il blocco "SEZIONE 1: Entries per scuola" (righe ~18-36). Sezione 2 e 3 invariate. |
| `app/assets/stylesheets/column-summary.css` | nuovo (~30 righe) | regole per `.column-summary__rows`, `.column-summary__row`, `.column-summary__row__header`, `.column-summary__row__cards`. |

## File NON toccati

- `app/controllers/columns_controller.rb` — invariato.
- `app/models/column/summary.rb` — invariato: `grouped_by_scuola` è già la struttura giusta `[[destinatario, entries_ordinate], …]`.
- `app/views/entries/_entry.html.erb` e partial figli (`_appunto`, `_documento`, `_tappa`) — già supportano `card--in-context` e bulk checkbox.
- `app/views/entries/bulk_bar/_bar.html.erb` — riusato as-is.
- `app/views/shared/_bulk_bar.html.erb` — riusato as-is.
- `app/javascript/controllers/bulk_actions_controller.js`, `bulk_bar_controller.js` — riusati as-is.
- Tutti gli endpoint bulk già citati.

## Markup finale (sezione 1)

```erb
<%# === SEZIONE 1: Entries per scuola === %>
<div data-controller="bulk-actions" data-action="click->bulk-actions#toggleCard">
  <%= render "entries/bulk_bar/bar" %>

  <div class="column-summary__rows">
    <% @summary.grouped_by_scuola.each do |dest, entries| %>
      <article class="column-summary__row">
        <header class="column-summary__row__header">
          <h3 class="overflow-ellipsis"><%= dest&.denominazione || "Senza destinatario" %></h3>
          <% if dest.respond_to?(:comune) && dest.comune.present? %>
            <span class="txt-subtle txt-small"><%= dest.comune %></span>
          <% end %>
          <span class="badge"><%= entries.size %></span>
        </header>

        <div class="cards cards--in-context column-summary__row__cards"
             data-controller="navigable-list">
          <% entries.each do |entry| %>
            <%= render "entries/entry", entry: entry, draggable: false %>
          <% end %>
        </div>
      </article>
    <% end %>
  </div>
</div>
```

## CSS nuovo

```css
/* app/assets/stylesheets/column-summary.css */
.column-summary__rows {
  display: flex;
  flex-direction: column;
  gap: var(--space-m, 1rem);
}

.column-summary__row {
  display: grid;
  grid-template-columns: minmax(180px, 220px) 1fr;
  gap: var(--space-m, 1rem);
  align-items: start;
  padding-block: var(--space-s, 0.5rem);
  border-block-end: 1px solid var(--color-divider, oklch(0.92 0 0));
}

.column-summary__row__header {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.column-summary__row__cards {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-s, 0.5rem);
}
```

(I valori esatti delle variabili `--space-*` e `--color-divider` vanno allineati a quelle già definite in `_global.css` / variabili Fizzy in uso nel progetto; sopra sono fallback indicativi.)

## Rischi / cose da verificare durante l'implementazione

- **Larghezza card "in-context"**: le card mostrate altrove con `cards--in-context` sono dentro un container `cards--grid` (CSS Grid). Qui le mettiamo in flex-wrap. Verificare che `--card-grid-columns` / `inline-size` della card non forzino larghezze che spezzano il wrap. Se serve, impostare `inline-size` o `max-inline-size` sulla card dentro `.column-summary__row__cards`.
- **`navigable-list`**: attualmente la show non lo aveva attivo. Lo aggiungo per coerenza con `_open_list` (selezione con hover/keyboard). Da testare che non confligga con `bulk-actions` (in `_open_list` coesistono già).
- **Performance**: `Column::Summary` carica già tutto in una query (`load_entryables`). Nessun N+1 nuovo introdotto.
- **Drag & drop disabilitato**: `draggable: false` come ora. La show non è la kanban; il drag è in dashboard.
- **Mobile**: con `grid-template-columns minmax(180px, 220px) 1fr` su mobile la cella sx diventa stretta ma resta. Eventuale media query a una colonna verticale solo se la UX su mobile risulta strozzata.

## Non-goals (esplicitamente fuori scope)

- Refactor di Sezione 2 (Volumi da consegnare).
- Refactor di Sezione 3 (Adozioni per scuola).
- Modifiche alle card singole (`_appunto`, `_documento`, `_tappa`).
- Nuovi endpoint bulk o nuove form bulk.
- Filtri/ordinamenti nuovi sulla show colonna.

## Test

Manuale, perché è una pagina visuale e usa pattern già coperti altrove:

1. Aprire show di una colonna con entries miste (scuole + classi + clienti).
2. Verificare che righe siano ordinate per denominazione scuola, e che entries di una stessa scuola siano ordinate per anno+sezione classe.
3. Verificare wrap delle card quando la riga si riempie.
4. Selezionare 1 entry → comparsa bulk bar. Selezionare entries di 2 scuole diverse → counter aggiornato.
5. Eseguire ogni azione bulk: Stato → colonna X, Completa, Da gestire, Stampa, Elimina, Gestione (dialog). Verificare che la show si aggiorni via Turbo / morph.
6. Verificare che Sezione 2 e Sezione 3 siano identiche a prima.

Nessun test Minitest aggiuntivo: niente nuova logica in controller/model.
