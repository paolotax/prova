# Schema partial card/perma per risorsa

Aggiornato: 2026-07-09 (dopo il refactoring di allineamento al pattern Fizzy).

Riferimento: Fizzy (`~/rails_2023/fizzy/app/views/cards/`).

## Il pattern (mutuato da Fizzy)

Ogni risorsa "cardabile" ha due rese:

- **preview** — la card compatta nelle liste (index, kanban). File: `display/_preview.html.erb`,
  renderizzata in collection da `display/_previews.html.erb`.
- **perma** — la card grande nella pagina show, avvolta in `.card-perma` con actions laterali
  e notch footer. File: `_container.html.erb` (+ sub-partial in `container/`).

Il partial "default" (`_documento`, `_scuola`, ecc.) è una **delega di una riga** a
`display/preview`: così `render record` e `render collection` funzionano ovunque.

Anatomia della card preview:

```
article.card                      ← id: dom_id(entry) se Entryable, altrimenti dom_id(record)
├── label.card__checkbox          ← solo risorse con bulk action
├── div.flex.flex-column…         ← wrapper (.flex.flex-column.flex-item-grow.max-inline-size)
│   ├── a.card__link              ← link overlay + for-screen-reader
│   ├── header.card__header
│   │   └── display/preview/_board  → shared/cards/display/preview/board (id + name)
│   ├── div.card__body > div.card__content   ← titolo, sottotitolo, dettagli
│   └── footer.card__footer
│       └── _meta                 ← slot fissi: added/author/updated/assignees/copie/importo
└── div.card__actions             ← bottoni laterali (solo scuole)
```

Anatomia della perma (show):

```
section.card-perma#dom_id(record, :container)   ← --card-color inline
├── .card-perma__actions--left    ← gild, pianifica, prev
├── .card-perma__bg > article.card
│   ├── header  → display/perma/_board (+ _tags)
│   ├── .card__body > .card__content  → container/_content o turbo_frame :edit
│   └── footer  → display/perma/_meta
├── .card-perma__actions--right   ← azioni, next
└── .card-perma__notch--bottom    → turbo_frame :footer → container/_footer
```

## Partial per risorsa

### Entryable (documenti, appunti, tappe)

Le card usano `dom_id(entry)` quando l'entry esiste (allineamento broadcast), supportano
`draggable` nel kanban e le collection sono renderizzate con `cached: true`.

| | documenti | appunti | tappe |
|---|---|---|---|
| delega | `_documento` | `_appunto` | `_tappa` |
| preview | `display/_preview` | `display/_preview` | `display/_preview` |
| collection | `display/_previews` (cached) | `display/_previews` (cached) | `display/_previews` (cached) |
| preview board | `display/preview/_board` → shared | idem | idem (con data tappa) |
| preview meta | `display/preview/_meta` | idem | idem |
| extra preview | `display/preview/_columns` | `display/preview/_columns` | `display/perma/_tags` nel header |
| perma | `_container` (+ Stimulus `documento-editor`) | `_container` | `_container` (prev/next per data) |
| perma board/meta/tags | `display/perma/_*` | `display/perma/_*` | `display/perma/_*` |
| container/ | actions, content, content_display, gild, stages, footer/, righe_table, gestione_dialog… | actions, content, content_display, gild, stages, footer/ | actions, content, gild, stages, footer, bolle_visione |
| varianti | `table/_row` (vista tabella) | `_bozza` (tray bozze), `display/common/_board` | `_tappa_compact` (+ ghost), `_pianifica` |
| bulk | `bulk_bar/`, `bulk_gestione/`, checkbox `ids[]` (entry id) | `bulk_bar/`, checkbox `ids[]` (entry id) | `bulk_bar/`, checkbox `ids[]` (**id tappa**: i controller bulk scopano `current_user.tappe`) |

### Anagrafiche (scuole, persone, libri)

Migrate al pattern preview il 2026-07-09. Niente `cached: true` per ora: le card contengono
contenuto per-utente (scuole) e i contatori non hanno `touch` sul padre (audit necessario
prima di attivare la cache).

| | scuole | persone | libri |
|---|---|---|---|
| delega | `_scuola` | `_persona` | `_libro` |
| preview | `display/_preview` | `display/_preview` | `display/_preview` (con thumbnail copertina) |
| collection | `display/_previews` (no cache, per-utente) | `display/_previews` | `display/_previews` |
| preview board | `display/preview/_board` → shared | idem | idem (+ prezzo nel header) |
| preview meta | riusa `display/perma/_meta` | — (niente meta) | `display/preview/_meta` |
| perma | `_container` (+ sezione `.scuola-show` sotto) | `_container` (+ `.scuola-show`) | `_container` |
| perma board | `display/perma/_board` → shared perma/board | idem | idem |
| container/ | content_display, edit_form, edit_footer, footer, classi, insegnanti, adozioni, disponibilita, prossime_visite, saggi | content_display, edit_form, edit_footer, footer, appunti, saggi | content_display, edit_form, edit_footer, footer, footer_display, fascicoli, fascicoli_tiles |
| varianti | `_direzione_group` (gruppo direzione+plessi in index) | `_search_dialog` | `_librino` (mini riga titolo+isbn+prezzo), `fascicoli/`, `movimenti/` |
| bulk | `bulk_bar/`, checkbox `ids[]` | — | `bulk_bar/`, checkbox `ids[]` |

### Classi (nested sotto scuole)

Nessuna card da index globale: la classe compare solo nella lista classi di una scuola e
dentro le card di documenti/appunti quando è `clientable`/`appuntabile` (`card__classe-badge`).

- lista: `scuole/classi/_classe_row` — panel/list-item cliccabile (NON una `.card`)
- tabella riassuntiva nella show scuola: `scuole/container/_classi` (griglia anni × combinazioni)
- perma: `scuole/classi/_container` (pattern card-perma, prev/next via locals)
- perma board/meta: `classi/display/perma/_board` e `_meta` → shared perma/board
- `container/`: content_display, edit_form, edit_footer, footer, docenti, adozioni, entries

### Shared (`app/views/shared/cards/display/`)

| partial | usato da | note |
|---|---|---|
| `preview/_board` | preview board di tutte e 6 le risorse | delega a common/_board |
| `common/_board` | (via preview/_board) | `div.card__board` con id+name |
| `perma/_board` | perma board di tutte le risorse + clienti + bulk_gestione | `label.card__board`, supporta yield per picker |

I tre `_meta` condivisi (preview/common/perma), parametrici e mai adottati, sono stati
rimossi il 2026-07-09.

## Convenzioni fissate (2026-07-09)

- **Interazioni card**: `mouseenter->navigable-list#hoverSelect` sempre; in più
  `contextmenu->navigable-list#toggleSelection` solo dove c'è selezione bulk con checkbox
  (documenti, appunti, scuole, libri). Niente `click->hoverSelect`.
- **Checkbox bulk**: sempre `name="ids[]"` (il bulk-actions JS propaga il nome al form;
  i controller leggono `params[:ids]`).
- **Perma board**: sempre `shared/cards/display/perma/board`; il preview board delega a
  `shared/cards/display/preview/board`.
- **Footer**: sempre `<footer class="card__footer full-width">` (o `flex gap-half`).
- **Logica fuori dalle view**: prev/next tappe in `TappeHelper#tappa_adjacent_ids`,
  JSON editor in `DocumentiHelper#documento_editor_json`/`documento_editor_righe_json`,
  bolle aperte in `Scuola#bolle_visione_aperte_count`.
- **Prev/next come locals**: i container di persone e classi ricevono
  `prev_/next_*_id` come locals dalla show (il controller li calcola in `load_prev_next`).
- **Niente cache sulle collection anagrafiche** (deciso 2026-07-09): le associazioni che
  alimentano le card non hanno `touch` sul padre (persona_classi, contatori libro — un
  `touch` lì martellerebbe i re-import MIUR) e la card scuola contiene contenuto per-utente
  (navigator, assegnatari). Rivalutare solo se le liste diventano lente; servirebbe
  `cached: ->(record) { [record, ...] }` con chiave composta e audit dei touch.

## Incoerenze residue / TODO

Nessuna nota al 2026-07-09. Il preview documenti ha il wrapper flex e le card tappa hanno
checkbox bulk — entrambe modifiche verificate con render reale ma da ricontrollare a occhio
in index documenti e agenda.

Storico 2026-07-09: bug fix (avatar autore su card appunto, meta nel footer su card tappa,
doppio style su container documento, `@scuola`→`scuola`, refuso `card__id-small`→`card__id`);
migrazione anagrafiche al pattern preview; ritocchi classi; interazioni canoniche;
rimozione `card--selected` (nessuna regola CSS/JS la usava); shared `_meta` eliminati;
spostamenti in `container/` (persone, classi) e rename `_classe_card`→`_classe_row`;
`libro_ids[]`→`ids[]`; secondo giro: checkbox bulk sulle card tappa (la selezione in agenda
era rotta: bulk bar senza checkbox), wrapper flex nel preview documenti, meta classi in
`display/perma`, prev/next via locals. Smoke test di resa:
`test/integration/cards_render_smoke_test.rb`.
