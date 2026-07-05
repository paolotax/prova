# Passaggio anno guidato — design

Data: 2026-07-05
Stato: approvato (opzione SQL aggregata per il conteggio match)

## Problema

I job per il passaggio anno scolastico esistono (`AggiornaCambiCodiceJob`,
`PromuoviScuolePromuovibiliJob`, `AggiungiScuoleNuoveJob`) e le action controller
pure (`aggiorna_cambi_codice`, `promuovi_tutte`, `aggiungi_scuole_nuove`), ma i
pulsanti sono sparsi e l'utente deve conoscere a memoria l'ordine dei passaggi.
Serve una sequenza guidata nella dashboard controllo adozioni.

## Decisioni prese

1. **Stato derivato dai contatori** — uno step è "fatto" quando il suo contatore
   è a zero. Nessuna persistenza, nessuna migrazione, il morph live
   (`turbo_stream_from Current.account, "controllo_adozioni_dashboard"`) aggiorna
   la sequenza da solo.
2. **Nessun badge "in corso"** — dopo il click il notice conferma l'avvio, i
   contatori scendono in tempo reale. Niente dipendenza da Sidekiq nella dashboard.
3. **Partial condiviso** — la sequenza appare sia nella dashboard admin
   account-wide sia nel drill-down provincia (job scoped con `provincia:`, che le
   action già accettano).
4. **Conteggio match in SQL aggregato** (opzione a) — il criterio "predecessore
   certo" di `Panoramica#cambi_codice` viene portato in una query account-wide
   nello stile di `Dashboard`, invece di materializzare Panoramica per provincia.

## La sequenza

| # | Step | Contatore | Azione |
|---|------|-----------|--------|
| 1 | Aggiorna cambi codice | codici nuovi con predecessore certo (`:match`) | `AggiornaCambiCodiceJob` |
| 2 | Promuovi le scuole | scuole promuovibili (`da_promuovere`) | `PromuoviScuolePromuovibiliJob` |
| 3 | Aggiungi scuole nuove | codici nuovi senza candidati (`:nuova`) | `AggiungiScuoleNuoveJob` |
| 4 | Rifinitura manuale | suggerimenti (`:suggerimento`) + anomalie | nessun job: link ai filtri |

Step 1 prima di step 2: il cambio codice rende la scuola promuovibile col nuovo
codice (il job accoda già la promozione per le scuole toccate). Step 3 dopo:
le nuove entrano in anagrafe già riconciliate all'anno corrente.

## Backend: `ControlloAdozioni::PassaggioAnno`

PORO in `app/models/controllo_adozioni/`, `new(account:, provincia: nil)`.
Espone `steps` — array di struct `{ key:, count:, job_path_helper:, filtro: }` —
e `anno` (da `NewScuola.maximum(:anno_scolastico)`, come Dashboard/Panoramica).

### Split dei "codici nuovi" in match / suggerimenti / nuove

Oggi `Dashboard#codici_nuovi_per_provincia` conta il pool in blocco. La
classificazione vive in `Panoramica#build_cambi_codice`:

- **orfana** = scuola account il cui codice non è più in `new_adozioni` (per tg
  del grado zona), esclusa se direzione;
- **candidata** = orfana dello stesso comune e stessa natura
  (statale/paritaria, `tipo_scuola ILIKE '%NON STATALE%'`);
- **predecessore certo** = esattamente una candidata con denominazione "simile"
  (uguale dopo normalizzazione `[^A-Z0-9 ]→spazio, squeeze, strip`, oppure una
  contenuta nell'altra);
- tipo: `match` se predecessore certo, `suggerimento` se candidate > 0 senza
  match univoco, `nuova` se zero candidate.

In SQL: normalizzazione con
`btrim(regexp_replace(upper(x), '[^A-Z0-9 ]', ' ', 'g'))` + collasso spazi
`regexp_replace(..., ' +', ' ', 'g')`; similarità con uguaglianza o
`position(a in b) > 0` nei due versi; per ogni codice nuovo si contano le
candidate e le simili (LATERAL o join aggregato per comune+natura) e si
classifica con `CASE`. Una query per grado di zona, come le query esistenti di
Dashboard.

**Guardia anti-deriva**: test che, su fixture condivise, confronta i conteggi
per tipo di `PassaggioAnno` con `Panoramica#cambi_codice.group_by(&:tipo)`.
Se la SQL e il Ruby divergono, il test fallisce.

### Riuso degli altri contatori

- `da_promuovere`: stessa subquery `promuovibile` di `Dashboard#sql_righe`
  (estratta in metodo condivisibile o duplicata con test di allineamento).
- `anomalie`: conteggio esistente.
- Con `provincia:` presente tutte le query filtrano su quella provincia.

## UI: partial `controllo_adozioni/_passaggio_anno.html.erb`

Renderizzato in cima a `dashboard.html.erb` e in cima al drill-down provincia
in `index.html.erb` (solo admin: le action fanno già `head :forbidden` per i
non admin, la UI non deve mostrare i pulsanti ai member).

- 4 step-card numerate in fila (stile Fizzy, CSS in `analytics.css` o modulo
  dedicato): numero, titolo, contatore grande, riga di descrizione, pulsante
  `button_to` con `turbo_confirm` (testo con provincia se scoped).
- Step a zero: check ✓, niente pulsante, stile attenuato.
- Step 4: link ai filtri esistenti (`filtro: "anomalie"`, drill-down suggerimenti).
- Il pulsante "Promuovi i match" oggi nella card `codici_nuovi` della dashboard
  viene rimosso (assorbito dallo step 1).
- Titolo sezione: "Passaggio anno <anno label>" usando l'anno dello snapshot.

## Test

- `test/models/controllo_adozioni/passaggio_anno_test.rb`: conteggi dei 4 step,
  split match/suggerimento/nuova, scoping provincia, anno assente (snapshot
  mancante → sequenza nascosta/vuota).
- Guardia anti-deriva PassaggioAnno ↔ Panoramica (stesso file).
- `test/controllers/controllo_adozioni_controller_test.rb`: sezione presente
  nella dashboard admin e nel drill-down, assente per i member.

## Fuori scope

- Storico lanci (chi/quando) — rimandato finché non serve.
- Badge job in corso via Sidekiq.
- Step per lo scraping MIUR (già automatico via cron).
