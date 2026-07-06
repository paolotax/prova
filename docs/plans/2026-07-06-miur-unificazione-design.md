# Unificazione tabelle MIUR + consolidamento passaggio anno — Design

Data: 2026-07-06
Stato: validato (brainstorming con Paolo)

## Contesto e motivazione

La review completa del sistema (import/aggiornamento MIUR + passaggio anno) ha
confermato: **il motore è solido, l'architettura dei dati no**. Il problema
strutturale è il dualismo `new_*`/`import_*`: due schemi per lo stesso dato
ministeriale, con convenzioni opposte (minuscolo vs MAIUSCOLO quotato) e chiavi
uniche divergenti. Conseguenza: ogni consumer è implementato due volte
(`Adozione::Reconciler` con la struct `Source`, le 3 matview in UNION,
`PrezzoMinisteriale` con due `popola_da_*`, le Stats con due query).

L'unificazione era stata proposta nel design 2026-04-25 e rinviata il
2026-06-26 perché il blue-green swap aveva risolto il dolore acuto (lo swap
manuale di luglio). Ma il costo *ricorrente* — ogni feature scritta due volte,
da ultima l'Anteprima — resta, e passaggio anno + anomalie + analytics sono
stati tutti costruiti sopra il dualismo. Ora si unifica.

Problemi rilevati dalla review, in ordine di gravità:

1. **Dualismo `new_`/`import_`** (la radice — vedi sopra). In più la
   promozione new→import è manuale con anno hardcoded (`import_2024`,
   `ImportAdozione.import_new_adozioni`): di fatto `import_adozioni` non è più
   alimentata dalla pipeline.
2. **Logica di dominio duplicata 3–5 volte**: promuovibilità in 5
   implementazioni (Panoramica, PassaggioAnno, Dashboard SQL,
   PromuoviScuolePromuovibiliJob, `Scuola#promuovibile?`); classificazione
   cambi codice in Ruby (`Panoramica#build_cambi_codice`) e in SQL
   (`PassaggioAnno::SQL_CLASSIFICA`) tenute allineate solo da un test
   anti-deriva; `denom_norm` vs `NORM`; `precedente(anno)` duplicato
   job/controller.
3. **Due motori di "costruisci classi+adozioni dal MIUR"**:
   `Scuola#promuovi_primaria!` (roster-based) vs `Adozione::Reconciler`
   (set-based).
4. **Anni scolastici hardcoded** in almeno 6 punti (`Reconciler#source`,
   `ReconcileAccountJob::ANNI`, `ImportScuolePerZonaJob`, `import_2024`,
   label view).
5. **Bug e codice morto**: `controllo_anomalie.anno_scolastico` mai popolato
   (colonna/indice/scope morti); `ImportAdozione#editore` (override con
   `.upcase` che ombreggia la `belongs_to` e rompe l'autosave); matview
   definite in due posti (migrazione + inline in `import.rake`); task legacy
   morti; `NewScuola` classe vuota.
6. **Interfaccia controllo_adozioni**: `index` a doppia personalità, query
   pesanti in loop nelle view, `show` con 6 ivar e query raw nel controller,
   4 POST RPC-style, label anni hardcoded.

## Decisioni (validate)

| Decisione | Scelta |
|---|---|
| Unificazione | Tabella unica **partizionata per `anno_scolastico`** |
| Naming | `miur_adozioni` / `miur_scuole`, modelli `Miur::Adozione` / `Miur::Scuola` in `app/models/miur/` |
| Motori | Ruoli separati: `promuovi_primaria!` = identità classi; adozioni scritte **solo** dal Reconciler |
| Riga scuola | **Stato-centrica**: un badge di stato + una sola azione contestuale |
| Stato dati | Barra stato in dashboard + tabella `miur_import_runs` con delta |
| Ordine | Fondamenta → logica → UI (ogni fase deployabile da sola) |
| `old_adozioni` | Backfill del 2024/25 in `miur_adozioni`, poi **drop** |
| `import_scuole` | **Resta per ora** (anagrafe durevole geocodificata, FK da `scuole`/`user_scuole`) — piano futuro in Fase 4 |

## Sezione 1 — Modello dati

### `miur_adozioni`

Tabella unica `PARTITION BY LIST (anno_scolastico)`, una partizione per anno
(`202425`, `202526`, `202627`, …). Colonne tutte minuscole, identiche alle
attuali di `new_adozioni`. Assorbe `new_adozioni`, `import_adozioni` e
`old_adozioni`.

- Chiave unica globale: `(anno_scolastico, codicescuola, annocorso,
  sezioneanno, combinazione, codiceisbn, disciplina)` — la chiave "giusta" già
  usata da `new_adozioni`, include la partition key per costruzione.
- Indici: gli stessi 4 attuali di `new_adozioni` (EE parziale, disc_anno_tg,
  codicescuola, unique classe).
- Niente timestamps: la partizione viene riscritta intera, la cronologia sta
  in `miur_import_runs`.

### `miur_scuole`

Stessa struttura partizionata, assorbe `new_scuole` (snapshot anagrafe per
anno). Mantiene il link `import_scuola_id` verso l'anagrafe durevole
(popolato post-swap come oggi), esposto come `belongs_to :anagrafe` sul
modello: il codice nuovo non parla mai direttamente con `import_scuole`, così
il rinominamento futuro (Fase 4) tocca un punto solo.

### `import_scuole` — resta

Non è uno snapshot ma l'**anagrafe durevole geocodificata** (slug,
latitude/longitude) a cui puntano le FK di `scuole`, `user_scuole`. Toccarla
ora allargherebbe troppo il raggio. Fuori scope; piano in Fase 4.

### `miur_import_runs`

Log degli import: `anno_scolastico`, `righe_totali`, `delta_righe`,
`regioni_aggiornate` / `regioni_stale` / `regioni_fallite` (jsonb),
`completed_at`. Alimenta la barra di stato in dashboard.

### Lo swap diventa banale (il guadagno più grosso)

Le matview `mercato_*` dipendono dalla tabella *padre*, non dalla partizione.
Il blue-green diventa: staging → dedup → indici → in transazione
`DETACH` + `DROP` della partizione dell'anno corrente e `ATTACH` della
staging. **Sparisce tutto il drop/recreate delle 3 matview** (il bug
rattoppato il 2026-07-04 in `import.rake`): basta un `REFRESH CONCURRENTLY`
a valle. Lo storico non viene mai riscritto.

### Backfill

`INSERT … SELECT` nelle partizioni dei rispettivi anni:

- `import_adozioni` (202526) mappando MAIUSCOLO→minuscolo;
- `old_adozioni` (202425, 3,52M righe — verificato: NON è un doppione, è
  l'unico posto dove esiste quell'anno) — poi drop della tabella;
- `new_adozioni` (202627) as-is;
- `new_scuole` → `miur_scuole`.

## Sezione 2 — Pipeline di import e scraping

**Il rollover di fine campagna sparisce.** Niente più copia manuale
new→import con anno hardcoded: l'anno nuovo è solo una partizione nuova;
"attiva" vs "archiviata" diventa un filtro su `anno_scolastico`.

**Task rake** (nuovo namespace `miur:`):

- `import:new_adozioni` → `miur:importa_adozioni`
- `import:new_scuole` → `miur:importa_scuole`
- `import:cambia_religione` → `miur:cambia_religione` (opera sulla partizione
  corrente)

Stessa struttura blue-green ma con swap di partizione. A fine run il task
scrive la riga di `miur_import_runs` (righe, delta sul run precedente, esiti
regioni passati dallo scraper).

**Scrapers**: `Miur::AdozioniScraper` e `ScuoleScraper` restano in
`app/services/miur/` (i runbook in CLAUDE.md li referenziano). Cambiano poco:
invocano i nuovi task e passano gli esiti regioni. La soglia CSV (18) va in
un solo posto — costante sullo scraper, letta dal task.

**Pulizia legacy contestuale**: rimozione di `import:miur_adozioni` /
`import:miur_scuole` (task interattivi HighLine, path vecchio),
`import_2024`, `splitta_adozioni` (no-op),
`ImportAdozione.import_new_adozioni`, dei task in `database_update.rake` /
`cache.rake` che toccano `old_adozioni`, e di `new_adozioni_stg` dallo schema.

## Sezione 3 — Consolidamento della logica di dominio

**Anno scolastico: una sola fonte.** Value object `AnnoScolastico`:
`Miur.anno_corrente` derivato da `Miur::Scuola.maximum(:anno_scolastico)`
(memoizzato), più `precedente`, `successivo` e `label` ("2026/27").
Sostituisce tutti gli hardcoded: `Reconciler#source`,
`ReconcileAccountJob::ANNI`, `ImportScuolePerZonaJob`, il fallback del
`PromozioniController`, le label nelle view, il duplicato `precedente(anno)`.

**Reconciler semplificato e unico motore adozioni.** La struct `Source`
sparisce: una tabella, un filtro anno. Stato attiva/archiviata derivato da
`anno == Miur.anno_corrente`. `Scuola#promuovi_primaria!` perde
`costruisci_adozioni!` e a fine promozione delega al Reconciler: l'ON
CONFLICT e la protezione dei dati utente (note, copie, `mia`) vivono in un
posto solo.

**Classificazione unica.** Nasce `ControlloAdozioni::Classificazione`:
l'unica implementazione set-based di match/suggerimento/nuova, promuovibilità
e promossa. La usano Panoramica, PassaggioAnno, Dashboard e i job. Il test
anti-deriva non serve più. `Panoramica` si restringe a raggruppamento
direzioni/plessi e righe.

**Fix puntuali:**

- `Rebuild` popola `controllo_anomalie.anno_scolastico` (colonna, indice e
  scope `per_anno` tornano vivi). Le anomalie restano globali, correttamente:
  i dati MIUR sono globali.
- `Miur::Adozione` nasce pulito sul modello di `NewAdozione`: **niente
  porting** dei metodi titleize né dell'override `editore` rotto di
  `ImportAdozione`.
- I consumer legacy che leggono `import_adozioni` con SQL raw
  (`agenda_controller`, `titoli_controller`) migrano a `miur_adozioni`;
  `ImportAdozione` si deprecata.

## Sezione 4 — Interfaccia controllo_adozioni

**Dashboard.** In alto la barra stato dati: "Dati MIUR aggiornati al 15/06 ·
3.159.400 adozioni (+146.430 dall'ultimo aggiornamento)", avviso giallo se ci
sono regioni stale/fallite (da `miur_import_runs`). Sotto, il passaggio anno
guidato com'è (solo step con contatore > 0), poi la tabella per provincia.

**Riga scuola stato-centrica.** La riga risponde solo a "questa scuola è a
posto?": nome, comune, codice, **un badge di stato** (✓ allineata / da
promuovere / cambio codice / N anomalie / non nel MIUR — calcolato da
`Classificazione`, priorità al problema più bloccante) e **una sola azione
contestuale** (Promuovi / Conferma codice / Vedi anomalie). Contatori cl/ad e
link anteprima escono dalla riga.

**Show scuola** diventa la pagina ricca: confronto classi/adozioni per anno,
anomalie per classe, link alle anteprime per anno corrente e precedente (label
da `AnnoScolastico`). La query `libri_per_classe` esce dal controller ed entra
in un PORO di presentazione accanto ad `Anteprima`.

**Controller e route in stile Rails/Fizzy.** Le 4 POST RPC-style diventano
piccoli controller dedicati: `ControlloAdozioni::CambiCodiceController#create`,
`PromozioniMassiveController#create`, `ScuoleNuoveController#create`,
`AnomalieController#create` — azioni magre, guard admin in `before_action`.
La doppia personalità di `index` si separa:
`ControlloAdozioni::DashboardController` per l'admin, `index` per la lista.
Le query in loop nelle view spariscono: `Panoramica` precomputa le righe in
batch.

## Fasi

Ogni fase è deployabile da sola.

1. **Fondamenta**: tabelle `miur_adozioni`/`miur_scuole` partizionate +
   `miur_import_runs`; backfill (incluso 202425 da `old_adozioni`); task
   `miur:*` con swap di partizione; migrazione consumer (Reconciler, matview,
   PrezzoMinisteriale, Stats, MCP tools, ControlloAdozioni::*); drop di
   `new_adozioni`, `import_adozioni`, `old_adozioni`, `new_scuole`; pulizia
   task legacy.
2. **Logica**: `AnnoScolastico`; Reconciler unico motore adozioni
   (`promuovi_primaria!` delega); `ControlloAdozioni::Classificazione`;
   fix `Rebuild`/anomalie.
3. **UI**: riga stato-centrica; barra stato dati; show ricca; controller
   dedicati REST; query fuori dalle view.
4. **(Futura, non ora) `import_scuole` → anagrafe durevole**: estrarre il
   valore (geocoding, slug) e non la tabella; `import_scuole` diventa
   l'anagrafe delle *identità* scuola (una riga per scuola, non per anno),
   rinominata es. `miur_anagrafe_scuole`; i dati che variano di anno in anno
   stanno in `miur_scuole` partizionata. Le FK esistenti restano valide
   perché puntano già a un'identità durevole. Il ponte `belongs_to :anagrafe`
   della Fase 1 rende il rename un cambio in un punto solo.

## Rischi e mitigazioni

- **Doppio funzionamento in transizione**: la Fase 1 migra i consumer uno a
  uno; finché non sono tutti passati, le vecchie tabelle restano in sola
  lettura. Il drop avviene solo a fine fase.
- **Volume backfill** (~10M righe totali): INSERT…SELECT per anno con indici
  creati dopo il load, fuori orario. Stesso pattern del blue-green.
- **Produzione**: il cron `adozioni_scraper` va messo in pausa durante il
  deploy della Fase 1 (o il task nuovo deve fare no-op se le tabelle nuove
  non esistono ancora).
- **Matview**: la migrazione le ridefinisce una volta sola su `miur_adozioni`
  (via UNION interna eliminata) — e sparisce la doppia definizione
  migrazione/rake.
