# Viste tabella generalizzate + colonne selezionabili + sort multi-colonna + shift multiselect

Data: 2026-07-12 · Branch: `feature/viste-tabella`

## Obiettivo

Estendere il toggle card/tabella dei documenti ad appunti, scuole e libri;
rendere le colonne definibili in codice (anche calcolate) e selezionabili
dall'utente; sort cliccabile sugli header con multi-sort via shift+click;
multiselect a intervallo con shift+click in tutte le liste; tabella
documenti più compatta.

## 1. Toggle vista (concern `HasVista`)

- `app/controllers/concerns/has_vista.rb`: `resolve_vista(default:)` — param
  `vista` ∈ {card, tabella} sovrascrive il cookie `"#{controller_name}_vista"`
  (1 anno). Estratto da `DocumentiController#resolve_vista`.
- Default: documenti `tabella`, appunti/scuole/libri `card`.
- Toggle header in partial condiviso `shared/_vista_toggle.html.erb`
  (riusa `vista_toggle_controller.js` invariato).
- Scuole: toggle sempre visibile; la vista tabella appiattisce i plessi anche
  con `sorted_by.per_direzione?` (il raggruppamento per direzione vale solo
  per le card). [Rivisto in corso d'opera: la prima versione nascondeva il
  toggle in per_direzione, ma per_direzione è il default e il toggle non si
  vedeva mai.]

## 2. Framework colonne (`app/models/data_table/`)

- `DataTable::Column` — value object: `key`, `label`, `width` (per grid),
  `align`, `partial` (default `"<risorse>/table/cells/<key>"`), `sort:`
  (frammento SQL whitelistato, opzionale → non sortabile), `scope:` (lambda
  applicata alla scope solo quando la colonna è visibile — per le calcolate),
  `default:` (visibile di default), `hide_mobile:`.
- `DataTable::Columns` — base class con DSL `column :key, ...` per i registri
  per risorsa: `Documento::Columns`, `Appunto::Columns`, `Scuola::Columns`,
  `Libro::Columns` (namespaced sotto il modello, convenzione POROs).
  API: `visible(keys)` (ordina secondo il registro, fallback ai default se
  keys vuote/invalide), `apply_scopes(scope, columns)`, `grid_template(columns)`.
- Aggiungere una colonna calcolata = un blocco `column` nel registro + un
  partial cella. Zero CSS, zero modifiche altrove.

## 3. Selezione colonne utente

- Bottone ingranaggio come ultima `th` della tabella (dentro il frame
  `search_results`, così si ri-renderizza con lo stato corrente).
- Popup stile Fizzy (`popup__list`, footer pinned con Applica): checkbox per
  colonna, "Ripristina default".
- Submit GET all'index con `colonne[]` + parametri correnti; il controller
  persiste in cookie JSON `"#{controller_name}_colonne"` e renderizza.
  Nessuna colonna selezionata → default.

## 4. Sort colonne

- Param URL `sort=comune.asc,denominazione.desc` — effimero (non entra nei
  filtri salvati), condivisibile, la paginazione lo conserva.
- `DataTable::Sort` — parse + whitelist dalle colonne visibili (sortabile ciò
  che ha `sort:`); chiavi sconosciute/nascoste ignorate in silenzio.
  Espone `order_clauses` (per `reorder`), `direction_for(key)`,
  `position_for(key)`, `toggle`/`to_param` helpers per le viste.
- Controller: se `sort` attivo → `scope.reorder(...)` sopra l'ordine del
  filtro; l'ordine del filtro resta il default.
- `column_sort_controller.js` sugli header: click = ciclo asc → desc →
  rimuovi (sort singolo, sostituisce gli altri); shift+click = aggiunge/cicla
  la colonna in coda mantenendo le altre. Naviga nel frame `search_results`
  con `turbo_action: advance`.
- Indicatori server-rendered nella `th`: freccia ↑/↓ + numero ordine in
  multi-sort; `aria-sort`.
- Con sort attivo si saltano i divider di raggruppamento (mese/provincia)
  che presumono l'ordine di default.

## 5. Tabella generica (CSS + partials)

- `app/assets/stylesheets/data-table.css`: `.data-table`, `.data-row`,
  `.data-row__*` derivate da `doc-table`/`doc-row`, con:
  - `grid-template-columns` da custom property `--cols` composta dalle width
    delle colonne attive (inline style sul container);
  - compattazione: padding block celle ~0.35ch (era 0.6ch), line-height più
    stretto, badge più piccoli — vale anche per documenti (richiesta
    "rimpicciolisci");
  - stili sort header e colonna gear;
  - mobile: solo checkbox + colonna principale (le altre `hide_mobile`),
    documenti conserva la riga valori dentro la cella cliente.
- Le regole `doc-table`/`doc-row` in `documento-table.css` vengono rimosse
  (restano `.documento-table` della show e `.doc-stato-tabs`).
- Header condiviso `shared/data_table/_header.html.erb` (columns, sort, gear).
- Righe per risorsa `<risorse>/table/_row.html.erb`: shell (id, classi,
  link overlay, checkbox `ids[]`, `navigable_list_target: item`) + loop sulle
  celle `<risorse>/table/cells/_<key>.html.erb`.

## 6. Colonne iniziali (tutte `default: true`)

- **Documenti** (le 9 attuali): stato, documento, collegati, cliente/scuola,
  copie (sort `totale_copie`), importo (sort `totale_cents`), consegna,
  pagamento; sort anche su documento (`data_documento`).
- **Appunti**: stato/board, nome+snippet, soggetto (appuntabile+comune),
  data creazione (sort `created_at`), sort su `nome`.
- **Scuole**: tipo (badge), denominazione, comune, prov, contatti, nr. mie
  adozioni (sort `mie_adozioni_count`); sort su denominazione/comune/
  provincia/tipo_scuola.
- **Libri**: copertina, titolo (sort), classe (sort), disciplina (sort),
  prezzo (sort `prezzo_in_cents`), contatori adozioni/fascicoli/confezioni
  (sort sui counter cache).
- Le calcolate arrivano dopo, definite alla bisogna nei registri.

## 7. Multiselect con shift (range)

- In `bulk_actions_controller.js` (già padre di tutte le liste): traccia
  l'anchor (ultima checkbox toccata senza shift); su shift+click applica lo
  stato dell'anchor a tutto l'intervallo anchor→target (stile Gmail).
- Shift+click su card/riga viene intercettato (preventDefault sul link
  overlay) e trattato come range select, non navigazione.
- Restano invariati: right-click toggle, Space, Shift+Enter da tastiera.
- Vale per tutte e 4 le risorse, in entrambe le viste.

## 8. Test

- Unit: `DataTable::Sort` (parse, whitelist, toggle), `DataTable::Columns`
  (visible/fallback/grid_template).
- Controller: cookie vista, param colonne→cookie, sort applicato/ignorato.
- Suite completa nel container dal worktree.

## Decisioni prese col committente

- Rimpicciolire = tabella documenti più densa (non le card).
- Sort solo nel param URL, non persistito.
- Scuole: tabella solo in vista flat.
- Selezione colonne in cookie per-browser; eventuale migrazione a preferenza
  DB in futuro senza toccare il resto.
