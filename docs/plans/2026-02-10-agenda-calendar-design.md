# Agenda Calendar Refactor — Stacked Weeks with Infinite Scroll

## Overview

Replace the current horizontal-scroll single-week agenda with a vertically stacked multi-week calendar inspired by HEY Calendar. Weeks are displayed one on top of the other with infinite scroll in both directions (past and future).

## Layout Structure

Each week is a full-width row with 7 day columns and a month label on the left:

```
┌─────────┬────────┬────────┬────────┬────────┬────────┬─────┬─────┐
│ FEBBRAIO│ LUN 9  │ MAR 10 │ MER 11 │ GIO 12 │ VEN 13 │ S14 │ D15 │
│ (90deg  │        │(today) │        │        │        │     │     │
│  faded) │ tappa  │ tappa  │        │ tappa  │        │     │     │
│         │ tappa  │        │        │        │        │     │     │
└─────────┴────────┴────────┴────────┴────────┴────────┴─────┴─────┘
┌─────────┬────────┬────────┬────────┬────────┬────────┬─────┬─────┐
│ FEBBRAIO│ LUN 16 │ MAR 17 │ MER 18 │ GIO 19 │ VEN 20 │ S21 │ D22 │
│ (90deg  │        │        │        │        │        │     │     │
│  faded) │        │        │        │        │        │     │     │
└─────────┴────────┴────────┴────────┴────────┴────────┴─────┴─────┘
```

### Specifics

- **Month label**: rotated 90deg on every week row, faded/subtle text. Shows the month name of the week's Monday.
- **Day columns**: Mon-Fri get equal width (~18% each), Sat-Sun get compact width (~5% each).
- **Week row height**: auto-grows to fit the tallest day's content. Empty weeks have a sensible min-height.
- **Gap between weeks**: small visual gap between rows.
- **Today**: date number highlighted with an orange pill/badge (like HEY).
- **Day header**: abbreviated day name + date number. Click navigates to `agenda/:giorno` show page.

## Tappa Compact Rendering

New partial `tappe/_tappa_compact.html.erb` for calendar-only display:

```
┌──────────────────────────────┐
│ IC Don Milani            [G1]│
│ Reggio Emilia                │
├──────────────────────────────┤
│ Al Portico di Gialdi     [G2]│
│ Campagnola Emilia            │
└──────────────────────────────┘
```

- **Nome scuola/cliente**: primary text, truncated with overflow-ellipsis.
- **Citta**: below, smaller and subtle.
- **Badge giro**: small colored box on the right with giro title abbreviation (e.g. "G1", "Ritiri").
- **Type distinction**: different color/icon for scuola vs cliente via `tappa_type_modifier`.
- **Click**: navigates to day detail page (`agenda/:giorno`).
- **Draggable**: each tappa is draggable to any visible day cell.

The existing `tappe/display/_preview.html.erb` partial remains unchanged for the show page.

## Infinite Scroll & Data Loading

### Initial Load

Controller loads 5 weeks: 2 past, current, 2 future. Page auto-scrolls to current week on load.

### Scroll Behavior

IntersectionObserver with two sentinel divs:

- **Sentinel top** (invisible div at the top): when visible, fetch 2 previous weeks via turbo_stream prepend. Adjust `scrollTop` to maintain visual position.
- **Sentinel bottom** (invisible div at the bottom): when visible, fetch 2 next weeks via turbo_stream append.
- **Loading flag**: prevents concurrent requests.

### Endpoints

```
GET /agenda                                          → HTML, 5 weeks
GET /agenda?giorno=YYYY-MM-DD&weeks=2&direction=append   → turbo_stream append
GET /agenda?giorno=YYYY-MM-DD&weeks=2&direction=prepend  → turbo_stream prepend
```

### Query

Single query for all visible weeks, grouped by date:

```ruby
current_user.tappe
  .where(data_tappa: start_date..end_date)
  .includes(:tappable, :giri)
  .group_by(&:data_tappa)
```

### "Oggi" Button

Sticky header button. Appears when the current week scrolls out of view (separate IntersectionObserver on the current-week element). Click smooth-scrolls to current week.

## Stimulus Controllers

### New: `agenda_calendar_controller.js`

Replaces `agenda_scroll_controller.js`. Responsibilities:

1. **Infinite scroll**: IntersectionObserver on top/bottom sentinels, fetch turbo_stream, adjust scrollTop after prepend.
2. **Scroll to today**: on connect, scroll to current week element.
3. **"Oggi" button visibility**: IntersectionObserver on current week row, toggle button visibility.

### Existing: Drag-and-Drop

Evolve `tappa_date_controller.js`:

- Every day cell is a drop target with `data-giorno="YYYY-MM-DD"`.
- Every compact tappa is `draggable="true"`.
- On drop to different day cell: PATCH to update `data_tappa`.
- Highlight target cell during dragover (colored border).
- Cross-week drag works naturally since all cells are in the DOM.

### Existing: `tax-sortable`

Stays unchanged for reordering tappe within a single day.

## Files to Change

### Views
- `app/views/agenda/index.html.erb` — vertical layout with sentinel divs, sticky header
- `app/views/agenda/_week.html.erb` — week row with 7 columns + rotated month label
- **New** `app/views/tappe/_tappa_compact.html.erb` — compact calendar rendering

### Controller
- `app/controllers/agenda_controller.rb` — multi-week loading, turbo_stream for append/prepend

### JavaScript
- **New** `app/javascript/controllers/agenda_calendar_controller.js` — infinite scroll, scroll-to-today, oggi button
- `app/javascript/controllers/tappa_date_controller.js` — adapt drop targets for vertical layout
- **Remove** `app/javascript/controllers/agenda_scroll_controller.js` — replaced by new controller
- **Remove** `app/javascript/controllers/scroll_to_day_controller.js` — no longer needed (was for horizontal snap)

### CSS
- Tailwind utilities only, no dedicated CSS file.
- Month label: `writing-mode: vertical-rl`, `text-orientation: mixed`, opacity for fade.
- Today pill: `bg-orange-400 rounded-full px-2` on the date number.
- Weekend columns: narrower width via grid or flex.

## Out of Scope

- Restyle of `agenda/:giorno` show page (separate task).
- Bulk actions bar for tappe (keep existing, adapt positioning if needed).
- PDF export actions (unchanged, accessed from show page).
- Map view (unchanged, accessed from show page).
- Slideover for adding tappe (keep existing, trigger from day header).

## Implementation Order

1. **Controller**: refactor `AgendaController#index` for multi-week loading with turbo_stream support.
2. **Week partial**: new `_week.html.erb` with vertical row layout, month label, 7 columns.
3. **Compact tappa partial**: new `_tappa_compact.html.erb`.
4. **Index view**: new `index.html.erb` with sentinel divs and sticky header.
5. **Stimulus controller**: `agenda_calendar_controller.js` with infinite scroll and scroll-to-today.
6. **Drag-and-drop**: adapt `tappa_date_controller.js` for new layout.
7. **Polish**: today highlighting, oggi button, visual refinements.
