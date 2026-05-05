# Sync MIUR + storicizzazione anno scolastico — Design

Data: 2026-04-25
Branch di partenza: `feature/multi-tenancy`

## Contesto

Il MIUR pubblicherà le adozioni 2026/27 a partire dal 25 maggio 2026 in modo
**cumulativo**: i dati arrivano per scuole man mano che la singola scuola
inserisce gli elenchi, e la pubblicazione si distribuisce su oltre un mese.
Lo scraping esistente (`AdozioniScraperJob` → rake `scrape:adozioni`) ha tre
problemi noti:

1. Bug: i sub-task `splitta_adozioni`, `import:new_adozioni`, ecc. sono
   invocati senza `.reenable`, quindi nel processo Sidekiq long-lived girano
   solo la prima volta.
2. Modello "swing" `new_adozioni` → `import_adozioni` → `old_adozione` con swap
   manuale via SQL a luglio (`db_update:scuole_e_adozioni`). Costoso da
   mantenere durante il rilascio cumulativo.
3. Mancanza di `anno_scolastico` esplicito in `Classe` e `Adozione`
   account-scoped → impossibile distinguere a.s. corrente da storico, nessuno
   snapshot riproducibile.

Inoltre lo schema multi-tenancy attuale aggancia `Scuola.codice_ministeriale`
al MIUR; il ~2% delle scuole italiane cambia `CODICESCUOLA` ogni anno
(accorpamenti, riorganizzazioni) → i tracking degli account si rompono.

## Decisioni architetturali

### 1. Schema dati storicizzato (tabella unica)

`import_scuole` e `import_adozioni` diventano tabelle uniche con
`anno_scolastico` esplicito (NOT NULL). Spariscono `new_adozioni`,
`old_adozione`, `new_scuole`.

```
import_scuole
  + anno_scolastico (NOT NULL, default null per record vecchi durante
    backfill)
  + tipo_dataset (enum: anagrafe_statale, anagrafe_paritaria,
    autonomia_statale, autonomia_paritaria)
  index (anno_scolastico, CODICESCUOLA) UNIQUE

import_adozioni
  + anno_scolastico (NOT NULL)
  index (anno_scolastico, CODICESCUOLA, ANNOCORSO, SEZIONEANNO,
         COMBINAZIONE, CODICEISBN, NUOVAADOZ, DAACQUIST, CONSIGLIATO) UNIQUE
```

Vantaggio: l'import 2026/27 scrive con `anno_scolastico='202627'` senza
toccare i record `'202526'`. Nessuna race condition possibile, lo swap di
luglio diventa un cambio di filtro WHERE.

### 2. Modelli account-scoped

```
Classe (entità persistente, evolve in-place)
  + data_inizio_anno_scolastico (es "202526" — a.s. di nascita della classe)
  + data_fine_anno_scolastico   (NULL = ancora attiva, valorizzato a fine ciclo)
  (anno_corso resta 1..5, viene incrementato dal job di promozione)

Adozione (storicizzata)
  + anno_scolastico (NOT NULL)
  belongs_to :classe
  + import_adozione_id → punta al record MIUR di quel a.s. specifico
```

Documenti, appunti, persone, tappe restano agganciati a `Classe` (che
persiste). La storia è preservata via `Adozione.where(anno_scolastico: …)`.

### 3. Stato polling

```
MiurDatasetState (modello globale, non multi-tenant)
  dataset_name (es "ALTABRUZZO" o "SCUANAGRAFESTAT")
  anno_scolastico
  last_modified_miur (data dal HTML "Modified: gg/mm/aaaa")
  last_imported_at
  n_righe
  status (idle|downloading|importing|completed|failed)
  error (text)
```

20 regioni × 1 dataset adozioni + 4 dataset scuole = 24 record di stato.

### 4. Pipeline job

```
MiurProbeJob (cron 3h)
  → fetch HTML pagina elements1 (adozioni + scuole)
  → per ogni dataset/regione: confronta last_modified vs MiurDatasetState
  → per ogni cambiato: enqueue MiurDatasetImportJob.perform_later(dataset)

MiurDatasetImportJob (per dataset/regione, lock per dataset)
  → download CSV (continua col formato esistente, JSON-LD è 3× più grande)
  → staging via activerecord-import in chunks
  → swap atomico in TX:
     DELETE FROM import_adozioni WHERE anno_scolastico=cur AND regione=R
     INSERT staging
  → calcola CODICESCUOLA changed
  → enqueue UpdateScuolaMieAdozioniJob per ogni scuola tracciata in
    qualche account (lookup via Scuola.where(codice_ministeriale: changed))
  → broadcast Turbo Stream su [account, "miur_status"] per refresh exit poll

ScuolaPromoteClassiJob (on-demand UI, per scuola)
  → per ogni Classe della scuola con data_fine_anno_scolastico=NULL:
     - se anno_corso==5 → data_fine = a.s. precedente (chiusura)
     - else → anno_corso += 1, aggiorna *_origine
  → per le adozioni del nuovo a.s. presenti in import_adozioni per la scuola:
     - crea Adozione(anno_scolastico=nuovo) per ogni Classe matchata
  → per le cl1 nuove: trova in import_adozioni nuove cl1 della scuola, crea
    Classe(anno_corso=1, data_inizio_anno_scolastico=nuovo)
```

### 5. Cambio codici ministeriali

Modello `ScuolaAlias`:

```
ScuolaAlias (globale o account-scoped — vedi sotto)
  codice_vecchio
  codice_nuovo
  anno_scolastico_transizione (es "202627")
  confidenza (auto_certo|auto_suggerito|manuale|chiusura)
  account_id (nullable: NULL = mapping globale, valorizzato = override account)
```

Heuristic di detection (verificata su transizione 2024/25 → 2025/26):
- match esatto `(comune + denominazione)` → 66% delle 1.392 scomparse
- ulteriore +7% con prefisso 10 char → arriva al 73%
- ~25% senza match → manuali

Job `DetectScuoleScomparseJob` triggerato dopo l'import dell'a.s. nuovo,
crea record `ScuolaAlias` con `confidenza=auto_certo` per match
deterministici, segnala il resto via UI.

Priorità bassa: l'editore (caso Bacherini) traccia tutte le scuole, quindi
in pratica anche se non rimappa quelle scomparse non perde dati operativi.
Implementare in seconda iterazione.

### 6. Exit poll — nuovi tab in adozioni_analytics

Aggiungere a `app/views/adozioni_analytics/show.html.erb`:

```
_tab_mie         (esistente)
_tab_editori     ← stats per editore (Stats::AdozioniQuery già pronto)
_tab_arrivate    ← scuole con almeno 1 adozione nel a.s. corrente, per zona
_tab_mancanti    ← scuole senza adozioni nel a.s. corrente, per zona
```

Aggiornamento real-time via Turbo Stream `[account, "miur_status"]`.

### 7. Stats

Modello `Stat` (template SQL salvati) resta come "templates di reportistica",
non più "freezer di risultati": con adozioni storicizzate, ricalcolare uno
stat di un a.s. passato è deterministico, non serve congelare.

## Frequenza polling

Cron 3h durante tutto l'anno. Durante maggio-luglio i dati arriveranno
cumulativi e il polling 3h darà latenza accettabile. La pagina HTML del MIUR
non ha rate limit dichiarato, 8 hit/giorno × 24 dataset = 192 GET/giorno.

## Step di implementazione (proposti, in ordine)

1. **Migration**: aggiungi `anno_scolastico` (Adozione, Classe), backfill,
   `data_inizio_anno_scolastico`/`data_fine_anno_scolastico` su Classe,
   `tipo_dataset` + indici su `import_scuole`/`import_adozioni`.
2. **Modello `MiurDatasetState`** + scaffold base.
3. **`MiurProbeJob`** + `MiurDatasetImportJob` (sostituiscono il rake legacy
   con `.reenable` mancante). Cron 3h.
4. **`ScuolaPromoteClassiJob`** + UI bottone "promuovi classi" sulla scuola.
5. **Tab exit poll** in `adozioni_analytics`.
6. **`DetectScuoleScomparseJob` + ScuolaAlias** + UI remap (priorità bassa).
7. **Cleanup**: rimuovi `OldAdozione`, `NewAdozione`, `NewScuola` e i rake
   `db_update:scorri_adozioni`. Conserva un export di sicurezza.

## Rischi e mitigazioni

- **Tabella `import_adozioni` cresce nel tempo** (~3.5M righe/anno). Indici
  giusti su `anno_scolastico` la rendono interrogabile. Pulizia `WHERE
  anno_scolastico < N anni fa` su soglia configurabile.
- **Migration heavy** (3.5M righe da aggiornare con `anno_scolastico`).
  Eseguire fuori orario con batch update + indice creato `CONCURRENTLY`.
- **Doppio import durante transizione** (legacy `new_adozioni` rake +
  nuovo job): per il primo run, disabilitare temporaneamente cron legacy.
- **Bug `.reenable` su scrape attuale**: documentato e bypassato dal nuovo
  job.

## Cosa NON è in questo piano

- Refactor `view_classi` (matview Scenic) — deprecata da CLAUDE.md, gestita
  separatamente.
- Refactor `Stats::AdozioniQuery` — già funzionante, riusato as-is dal tab
  Editori.
- Notifiche email/push agli utenti — solo Turbo Stream interno.

## Prossimi passi operativi

Aprire un piano di implementazione passo-passo (skill `writing-plans`) sui
7 step sopra, lavorando su un worktree dedicato (skill `using-git-worktrees`)
ad evitare conflitti col branch corrente `feature/multi-tenancy`.
