# MIUR Import Diff — design

**Data:** 2026-07-08
**Stato:** design validato, implementazione da fare
**Ambito:** solo il documento (nessun codice ancora)

## Problema

Il MIUR pubblica periodicamente **rettifiche** alle adozioni (es. l'invio dell'8 lug 2026:
+1.329 righe su 734 scuole già esistenti, 0 scuole nuove, 0 sparite). L'import
`miur:importa_adozioni` è uno **swap di partizione blue-green**: sostituisce in blocco
la partizione `miur_adozioni_<anno>`. Dopo lo swap non resta traccia di *cosa* è
cambiato rispetto al giro precedente.

Due necessità:

1. **Visibilità** — avere un diff dettagliato ad ogni importazione (oggi lo si ricostruisce
   a mano confrontando fingerprint per-scuola tra due dump).
2. **Rettifiche vs promozioni** — se l'utente ha già promosso delle scuole (materializzato
   `classi`/`adozioni` per l'anno), come si applicano le correzioni senza distruggere il
   suo lavoro?

## Contesto: il Reconciler già gestisce l'applicazione

`Adozione::Reconciler` (`app/models/adozione/reconciler.rb`) ricostruisce le adozioni
dell'utente da `miur_adozioni` in modo **idempotente e set-based**, per
`(account, provincia, anno)`. Applicato a un anno **già promosso**, una rettifica si
propaga in sicurezza:

- **Adozioni aggiunte dal MIUR** → `INSERT ... ON CONFLICT (classe_id, codice_isbn,
  anno_scolastico) DO NOTHING`: entrano le nuove, le righe esistenti (con `note`,
  `numero_copie`, `mia`, `libro_id`) **non vengono riscritte**.
- **Adozioni rimosse dal MIUR** → `cancella_adozioni_orfane`: le cancella, **ma protegge**
  quelle con lavoro utente/editore (consegne saggio, `numero_copie <> 0`, `note`, `mia`).
  Le protette vengono loggate, non cancellate.

Quindi "come applico le rettifiche a scuole già promosse?" → **ri-lanciare
`ReconcileAdozioniJob(account, provincia, anno)`**. Il difficile (non distruggere il lavoro
manuale) è già risolto. Manca la **visibilità** e un modo **agevolato ma manuale** di
scatenare l'applicazione.

## Principio guida

Il diff è **puro MIUR-vs-MIUR**, senza aggancio all'account. Confronta staging (nuovo)
contro partizione vecchia, lo segnala, e **l'utente decide** cosa farne con i flussi che
già esistono (promozioni, reconcile). Il sistema **non** fa re-reconcile automatico.

La distinzione "scuola già esistente vs nuova vs sparita" si ricava dai **dati MIUR stessi**,
non dallo stato di promozione dell'account:

- **Esistente** = `codicescuola` presente **sia** nella vecchia partizione **sia** in staging
  → i cambiamenti riga (isbn +/−) sono **rettifiche** → interessa il dettaglio riga.
- **Nuova** = `codicescuola` **solo** in staging → comparsa ora → solo **conteggio**,
  rimanda al flusso "da promuovere" (`PassaggioAnno`).
- **Sparita** = `codicescuola` **solo** nella vecchia → eliminata / cambio codice →
  **segnalata** (spesso è un cambio `CODICESCUOLA`).

## Blocco 1 — Calcolo e persistenza del diff

**Dove:** dentro `miur:importa_adozioni`, **prima dello swap** (`lib/tasks/miur.rake:188`),
quando vecchia partizione `miur_adozioni_<anno>` e staging `miur_adozioni_stg` sono
entrambe nel DB. Diff SQL puro, nessun export su file.

**Chiave di confronto:** la class-key già usata per l'unique index —
`(codicescuola, annocorso, sezioneanno, combinazione, codiceisbn, disciplina)`.

**Passi:**

1. Due `EXCEPT` (staging vs vecchia) → righe **aggiunte** e **rimosse**.
   Una scuola che "cambia libro" appare come 1 rimossa + 1 aggiunta sulla stessa classe.
2. Classifica ogni `codicescuola` toccato in **esistente / nuova / sparita** confrontando
   la presenza nelle due partizioni (non nell'account).
3. Persisti, legato a `Miur::ImportRun` (già esistente):
   - **sempre**, il **riepilogo** per `provincia × tipogradoscuola`: righe +/−, e i tre
     conteggi scuole (esistenti-con-rettifiche / nuove / sparite). Poche righe, sostenibile
     anche per il big-bang di inizio campagna.
   - **solo per le scuole esistenti**, il **dettaglio riga**: `codicescuola, codiceisbn,
     segno (+/−)` (con titolo/disciplina denormalizzati per la UI). Le nuove/sparite
     restano conteggi.

Il dettaglio riga resta piccolo **per costruzione**: le rettifiche su scuole già note sono
poche; l'import massivo di inizio anno è quasi tutto "scuole nuove" → conteggi, non milioni
di righe. (Una soglia di sicurezza sul numero di righe di dettaglio è opzionale, non
necessaria data questa proprietà.)

**Nuova tabella** (bozza): `miur_import_diffs`
- `import_run_id` (FK logica a `miur_import_runs`)
- `anno_scolastico`
- riepilogo: righe JSON o tabella figlia `provincia, tipogradoscuola, righe_aggiunte,
  righe_rimosse, scuole_esistenti, scuole_nuove, scuole_sparite`
- dettaglio (scuole esistenti): tabella figlia `codicescuola, codiceisbn, segno, titolo,
  disciplina`

(La forma esatta — JSONB vs tabelle figlie — si decide in fase di piano.)

## Blocco 2 — Come si mostra il diff

L'azione resta all'utente: due livelli, un **segnale** e una **pagina navigabile**.

**Segnale — mail dello scraper.** `ScrapingNotificationJob` già invia l'email post-import
(regioni aggiornate/stale/fallite). Si aggiunge una riga di sintesi dall'ultimo `ImportRun`:

> Rettifiche 8 lug: +1.329 righe su 734 scuole esistenti · 0 nuove da promuovere · 0 sparite.
> Province più toccate: Roma, Bari, Avellino. → *vedi dettaglio*

con link alla pagina.

**Pagina — storia import con drill-down.** Nuovo `Miur::ImportRunsController` (index + show),
**standalone** in `/miur/import_runs` (il diff è MIUR-globale, non account/provincia-scoped),
con **rimando dalla freshness** ("Dati MIUR aggiornati al…" → dettaglio import).

- **index**: elenco import (più recente in cima), ognuno con la sintesi (righe +/−, 3
  conteggi scuole, delta totale). Filtrabile per **provincia**.
- **show**: breakdown **provincia × grado**, poi drill nella scuola → **dettaglio riga**
  (isbn aggiunti/tolti con titolo/disciplina) per le scuole esistenti. Le **nuove** come
  conteggio con link allo step "promuovibili" del `PassaggioAnno`; le **sparite** come
  elenco da controllare.

**Nessuna azione automatica**: la pagina è informativa/navigazionale.

## Blocco 3 — Applicare le rettifiche (manuale, agevolato)

Dalla show di un import, **una convenienza, non un automatismo**: accanto a ogni provincia
con rettifiche su scuole esistenti, un bottone **"Ri-reconcilia questa provincia"** che
accoda `ReconcileAdozioniJob(account, provincia, anno)` per gli account interessati. È
l'utente a cliccarlo.

È sicuro per le protezioni del reconciler (vedi sopra: `DO NOTHING` + protezione orfane).

**Caso semantico da segnalare esplicitamente:** il **cambio-libro su riga protetta**. Se il
MIUR sostituisce un ISBN in una classe (−vecchio, +nuovo) e sul vecchio l'utente aveva già
lavorato, il reconciler aggiunge il nuovo ma **tiene** il vecchio (protetto) → coesistono
entrambi. Il diff vede "−isbn_A / +isbn_B sulla stessa classe" e può marcare la coppia come
**"sostituzione da verificare"**: l'utente decide se archiviare la vecchia adozione a mano.
Non è automatizzabile senza rischiare di buttare il suo lavoro.

## Flusso complessivo

```text
miur:importa_adozioni
  └─ (pre-swap) calcola diff staging vs vecchia partizione (class-key EXCEPT)
       ├─ classifica codicescuola: esistente / nuova / sparita
       └─ persiste su miur_import_diffs (riepilogo sempre, dettaglio solo esistenti)
  └─ swap partizione (invariato)

ScrapingNotificationJob → email con sintesi diff + link

/miur/import_runs (standalone, link da freshness)
  ├─ index: storia import, filtro provincia
  └─ show: provincia×grado → scuola → righe +/−
       ├─ nuove   → link a PassaggioAnno "promuovibili"
       ├─ sparite → elenco da controllare (possibili cambi codice)
       └─ esistenti → dettaglio rettifiche + "sostituzione da verificare"
            └─ [bottone] Ri-reconcilia provincia → ReconcileAdozioniJob (manuale)
```

## Fuori scope (YAGNI)

- Re-reconcile automatico post-import.
- Diff riga per l'import massivo di inizio campagna (solo conteggi).
- Risoluzione automatica delle sostituzioni su righe protette (sempre manuale).
- Qualsiasi accoppiamento del motore di diff con gli account.

## Riferimenti codice

- `lib/tasks/miur.rake` — `miur:importa_adozioni` (swap), punto di innesto del diff (~riga 188)
- `app/models/miur/import_run.rb` — modello esistente da estendere/collegare
- `app/models/adozione/reconciler.rb` — upsert `DO NOTHING` + `cancella_adozioni_orfane` (protezioni)
- `app/jobs/reconcile_adozioni_job.rb` — job per-provincia da scatenare a mano
- `app/models/controllo_adozioni/passaggio_anno.rb` — flusso promozioni (destinazione "scuole nuove")
- `app/services/miur/adozioni_scraper.rb` — `ScrapingNotificationJob` per il segnale email
