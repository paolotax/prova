# Passaggio anno + storicizzazione classi/adozioni — Design

Data: 2026-06-26
Branch di partenza: `main`

## Contesto

Aggiorna e rende concreto il design [2026-04-25 MIUR sync + anno scolastico
storicizzato](2026-04-25-miur-sync-anno-scolastico-design.md), allineandolo allo
stato reale del codice (quel piano è rimasto fermo allo step 1 parziale):

- Le tabelle MIUR legacy **non** sono state unificate: restano `new_adozioni`
  (anno corrente, sorgente scraping), `import_adozioni` (anno scorso, set
  "stabile"), `old_adozioni` (due anni fa). Lo swing `new_→import_→old_` resta.
- È stato aggiunto il **blue-green swap** su `import:new_adozioni` (staging +
  swap atomico): risolve il dolore principale dello swing manuale di luglio.
- È stato aggiunto lo **scraper anagrafica scuole** (`Miur::ScuoleScraper`,
  commit `5f58c10b`): `new_scuole` è ora l'anagrafe corrente 2026-27.
- Le colonne `anno_scolastico` su `adozioni`/`import_adozioni` esistono ma sono
  **vuote** (storicizzazione mai attivata).

Decisione operativa (concordata): **non** unifichiamo le tabelle MIUR ora.
Storicizziamo i **dati account** (`classi`/`adozioni`), che è ciò che serve per
il passaggio all'anno successivo.

## Problema

Il ~2% delle scuole cambia `CODICESCUOLA` ogni anno (accorpamenti,
riorganizzazioni). Caso reale: Calamandrei di Zola Predosa `BOEE17201L`
(2025-26) → `BOEE86402R` (2026-27), con tutta la D.D. rinumerata. Conseguenze:

- Una `Scuola` tracciata col codice vecchio non trova più le adozioni (che in
  `new_adozioni` stanno sotto il codice nuovo) → appare "non rilevata".
- Non esiste un meccanismo di **scorrimento anno**: `ImportScuolePerZonaJob`
  costruisce classi/adozioni da `ImportAdozione` ed è idempotente su
  `(scuola, anno_corso, sezione, combinazione)` → ri-aggancia allo stesso slot,
  non fa avanzare le coorti.

Il perno: le adozioni si legano alla **`Classe`** via
`codice_ministeriale_origine` (+ `classe_origine`, `sezione_origine`), **non** a
`Scuola.codice_ministeriale`. Quindi un "cambio codice" è ri-puntare gli
`*_origine` delle classi, e lo scorrimento anno è avanzare le classi + ripuntare
agli `new_adozioni` del nuovo anno.

## Sezione 1 — Modello dati storicizzato

`Classe` è l'entità **durevole** (a cui restano agganciati documenti, appunti,
persone, tappe); `Adozione` diventa lo **snapshot annuale**.

**`Adozione`** (qui vive la storia):
- `anno_scolastico` (es. `"202627"`) — colonna già esistente, oggi nil → da
  popolare e usare come discriminante.
- `codicescuola` — **nuovo campo**: snapshot del codice MIUR che ha generato
  l'adozione.

Così l'anno scorso resta interrogabile:
`classe.adozioni.where(anno_scolastico: "202526")` porta il codice **vecchio**;
le adozioni nuove portano il codice **nuovo**.

**`Classe`** (durevole, evolve in-place):
- `anno_scolastico` (a.s. corrente della classe) — **nuovo campo**.
- `stato` per archiviare le 5ª chiuse.
- allo scorrimento: `anno_corso +1` e `codice_ministeriale_origine` ri-puntato al
  codice nuovo.

**`Scuola`**: `codice_ministeriale` passa al nuovo. Il vecchio codice **non**
serve più come dato (è preservato negli snapshot `Adozione`); `note` lo conserva
solo come comodità/audit.

**Conseguenza:** la tensione vecchio/nuovo codice sparisce — non sovrascriviamo
nulla di storico, perché lo storico è negli snapshot `Adozione`, non sul
puntatore `origine` (sempre "anno corrente").

Le tabelle MIUR `new_/import_` restano come sorgente: la storicizzazione sta sui
dati account.

## Sezione 2 — Flusso di scorrimento anno + maschera remap

**Sorgente del nuovo anno:** direttamente da **`new_scuole`/`new_adozioni`**
(2026-27), senza aspettare lo swing manuale `new_→import_`. Lo swing resta per lo
storico; il rollover account attinge al fresco.

**Operazione `PromoteClassi` (per scuola, anno N→N+1)** — riusa le 3 fasi di
`ImportScuolePerZonaJob` ma con coscienza dell'anno:

1. **Snapshot**: le adozioni esistenti vengono taggate `anno_scolastico = N` +
   `codicescuola` (se non già) → diventano storia.
2. **Risolvi codice**: se `scuola.codice` è ancora in `new_scuole` → invariato;
   se è sparito → usa il codice nuovo deciso dalla maschera.
3. **Scorri le classi** (in-place, `Classe` durevole): 5ª → archiviata; le altre
   `anno_corso +1` e `*_origine` ri-puntati a `(codice nuovo, anno_corso+1,
   sezione)`. Stessa coorte, grado che avanza → documenti/appunti/persone restano
   attaccati.
4. **Costruisci adozioni N+1** da `new_adozioni` per ogni classe (via origine
   aggiornato) con `anno_scolastico = N+1`; crea le nuove **cl.1** dalle classi
   prime presenti in `new_adozioni` e non ancora esistenti.
5. Ricalcola `mia/disdetta` (riusa `UpdateScuolaMieAdozioniJob`) e i counter per
   N+1.

**Maschera remap (in `controllo_adozioni`)** — front-end che alimenta il passo 2:
elenca le scuole tracciate il cui codice è sparito da `new_scuole` (vedi query in
appendice), con accanto il **codice nuovo suggerito** (plesso stesso comune, con
adozioni in `new_adozioni`, non ancora tracciato). I match certi pre-selezionati;
confermi → aggiorna `scuola.codice_ministeriale`, annota il vecchio in `note`, e
lancia `PromoteClassi`.

## Sezione 3 — Edge case, sicurezza, implementazione, test

**Edge case & error handling:**
- **Rilascio cumulativo MIUR**: `new_adozioni` si riempie in settimane ⇒
  `PromoteClassi` solo per scuole già `rilevata` in `new_adozioni`. Le altre
  restano a N, si rilanciano dopo. Idempotente e ripetibile.
- **Doppio avanzamento**: guardia su `anno_scolastico` della classe — se già
  N+1, skip. Promote keyed sul target a.s., non cieco `+1`.
- **Collisione unique index** `(scuola, anno_corso, sezione, combinazione)`
  durante l'avanzamento: avanzare in ordine **decrescente** (archivia 5ª → 4→5,
  3→4, …) o vincolo deferrable.
- **Match codice incerto**: "certo" = **un solo** plesso non tracciato in
  `new_scuole`, stesso comune **e** grado, con adozioni. Il resto è proposta da
  confermare (il nome può cambiare, es. Calamandrei).
- **Reversibilità**: lo storico è negli snapshot `Adozione` (a.s. N) → intatto.
  Promote per-scuola in **transazione**; per annullare basta riportare
  `anno_corso` e cancellare le adozioni N+1. Log/evento promote per audit.

**Superficie d'implementazione:**
- *Migration*: `anno_scolastico` su `classi`; `codicescuola` su `adozioni` (+
  popolare `anno_scolastico`); `stato`/archiviata su `classi`; backfill esistente
  → `'202526'`; indici `(account_id, anno_scolastico)`.
- *Dominio*: `Scuola#promuovi_classi!(a_s:)` + `ScuolaPromoteClassiJob`; scope
  `Classe.attive(a_s)`; builder adozioni adattato a `new_adozioni` (estratto da
  `ImportScuolePerZonaJob`).
- *UI*: action/tab remap in `controllo_adozioni`, pattern turbo_frame + dialog
  (come `giri/tappe/copia/new.html.erb`).

**Test (minitest + fixtures):** avanzamento + archivio 5ª + nuove cl.1; tag
snapshot a.s. N; idempotenza (doppio run); remap aggiorna origine e costruisce
dal codice nuovo; solo scuole con `new_adozioni` promosse.

## Cosa NON è in questo piano

- Unificazione tabelle MIUR `new_/import_/old_` (resta lo swing + blue-green).
- `ScuolaAlias` come modello dedicato: il dato vecchio→nuovo è negli snapshot
  `Adozione`; il `note` basta per l'audit. Si potrà aggiungere se servirà una
  mappatura globale.
- Refactor di `Stats::AdozioniQuery` / matview rollup.

## Appendice — Query controllo (già in uso)

Stato per scuola tracciata dell'account, robusta ai cambi codice (rilevata /
cambio codice / non rilevata), che esclude le "non rilevata" senza adozioni
nemmeno l'anno scorso:

```sql
SELECT
  COALESCE(ns.provincia, import_scuole."PROVINCIA", s.provincia) AS provincia,
  COALESCE(ns.comune, import_scuole."DESCRIZIONECOMUNE", s.comune) AS comune,
  COALESCE(ns.denominazione_istituto_riferimento, import_scuole."DENOMINAZIONEISTITUTORIFERIMENTO") AS direzione,
  COALESCE(ns.denominazione, import_scuole."DENOMINAZIONESCUOLA", s.denominazione) AS scuola,
  s.codice_ministeriale AS codice,
  CASE
    WHEN na.codicescuola IS NOT NULL THEN 'rilevata'
    WHEN ns.codice_scuola IS NULL THEN 'cambio codice / cessata'
    ELSE 'non rilevata'
  END AS stato
FROM scuole s
LEFT JOIN new_scuole ns ON ns.codice_scuola = s.codice_ministeriale
LEFT JOIN import_scuole ON import_scuole."CODICESCUOLA" = s.codice_ministeriale AND import_scuole."ANNOSCOLASTICO" = '202526'
LEFT JOIN (SELECT DISTINCT codicescuola FROM new_adozioni) na ON na.codicescuola = s.codice_ministeriale
LEFT JOIN (SELECT DISTINCT "CODICESCUOLA" AS cod FROM import_adozioni) ia ON ia.cod = s.codice_ministeriale
WHERE s.account_id = :account_id
  AND (COALESCE(ns.codice_istituto_riferimento, import_scuole."CODICEISTITUTORIFERIMENTO") IS NULL
       OR s.codice_ministeriale <> COALESCE(ns.codice_istituto_riferimento, import_scuole."CODICEISTITUTORIFERIMENTO"))
  AND (na.codicescuola IS NOT NULL OR ns.codice_scuola IS NULL OR ia.cod IS NOT NULL)
ORDER BY provincia, comune, direzione, scuola;
```

## Prossimi passi

Aprire un piano d'implementazione passo-passo (skill `writing-plans`) sui pezzi:
migration storicizzazione → `PromoteClassi` + job → builder da `new_adozioni` →
maschera remap in `controllo_adozioni` → test.
