# Passaggio anno — riordino e ridefinizione degli step

> Design validato con l'utente 2026-07-07 (brainstorming). Niente worktree, branch corrente. TDD.

## Obiettivo

Riordinare e ridefinire i 4 step della sequenza guidata del passaggio anno (`ControlloAdozioni::PassaggioAnno`), come da decisione utente.

## Nuova sequenza

| # | key | Titolo | Badge (count) | Job bulk | Azione bulk su |
|---|---|---|---|---|---|
| 1 | `promuovibili` | Promuovi le scuole | `promuovibili` | `promuovi_tutte` | tutti |
| 2 | `cambi_codice` | Aggiorna i cambi codice | `match` | `aggiorna_cambi_codice` | tutti |
| 3 | `scuole_nuove` | Codici nuovi e suggerimenti | `nuova + suggerimento` | `aggiungi_scuole_nuove` | solo `nuova` |
| 4 | `anomalie` | Anomalie | `anomalie` | — (manuale: Ricalcola) | — |

Cambi rispetto a oggi: (1)↔(2) scambiati; step 3 assorbe i `suggerimento` (prima nel 4);
step 4 rinominato `rifinitura`→`anomalie`, conta solo le anomalie.

Riordino sicuro: promuovi (codice invariato) e cambi-codice (codice cambiato) agiscono su
insiemi disgiunti; `nuova`/`suggerimento`/`anomalie` non dipendono dagli step precedenti.

## Step 3: bulk nuove + lista manuale suggerimenti

- Pulsante **"Aggiungi le scuole nuove"** (bulk `AggiungiScuoleNuoveJob`, tocca solo i `nuova`);
  mostrato se `bulk_count > 0`.
- Link **"Da verificare (N)"** → filtro client-side `verifica` (riusa `selectChip` con
  `data-filter="verifica"`); mostrato se `verifica_count > 0`. I suggerimenti si confermano
  a mano dalle card `_riga_mancante` (azione `:scegli`) già presenti nella lista.

## Modifiche

1. **`app/models/controllo_adozioni/passaggio_anno.rb`** — riordino array `steps`; nuovi
   membri `Step`: `bulk_count` (default = `count`) e `verifica_count` (default 0); metodi
   `bulk`/`verifica`; `azionabile?` ora su `bulk` non su `count`.
2. **`app/helpers/controllo_adozioni_helper.rb`** — `STEP_FILTER_KEY`:
   `promuovibili→"promuovi"`, `cambi_codice→"cambio"`, `scuole_nuove→"nuove"`, `anomalie→"anomalie"`.
   (`PASSAGGIO_STEP_PATHS` invariato: mappa per `step.job`, i job non cambiano.)
3. **`app/views/controllo_adozioni/_passaggio_anno.html.erb`** — blocco azioni per-step:
   step 4 = Vedi anomalie + Ricalcola; step 3 = bulk nuove + "Da verificare"; 1/2 = Avvia.
4. **`app/javascript/controllers/controllo_adozioni_filter_controller.js`** — sostituire
   `RIF/"rifinitura"` con `COMPOSITES = { nuove: ["nuova","verifica"] }` (matchStato + count).
5. **Test**: `passaggio_anno_test` (ordine, split step 3, rename step 4);
   `controllo_adozioni_controller_test` (titolo "Anomalie" al posto di "Rifinitura manuale").

## Verifica

`docker exec prova-app-1 bin/rails test test/models/controllo_adozioni test/controllers/controllo_adozioni_controller_test.rb test/controllers/controllo_adozioni/ test/jobs/`
+ controllo visivo su localhost:3000.
