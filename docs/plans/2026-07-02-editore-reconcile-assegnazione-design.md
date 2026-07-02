# Editore: reconcile in blocco + analytics/assegnazione — Design

Data: 2026-07-02
Branch di partenza: `main`

## Contesto

L'account **s.bacherini@giunti.it** è un **editore**, non un agente: traccia
*tutte* le scuole d'Italia (oggi ~16.833, in crescita fino a copertura
nazionale). Il flusso attuale di `controllo_adozioni` + passaggio anno è disegnato
per un **agente** (territorio limitato, poche zone, gestione scuola-per-scuola) e
non regge la scala nazionale:

- **Pagina lenta** (~8-9s): `ControlloAdozioni::Panoramica` calcola tutto
  sull'intero account in sincrono al load (gruppi su 16k scuole, `new_counts`,
  `cambi_codice`, `conteggi_stati`, `promuovibili`), anche i pannelli admin.
- **Promozione dispendiosa**: `PromuoviScuolePromuovibiliJob` fa **un job per
  scuola** (`ScuolaPromuoviClassiJob`) → coda `bulk` da 16k, laptop a 100°C,
  ore di elaborazione, `promuovi_primaria!` con merge roster/insegnanti che al
  primo giro non serve (nessuno stato operativo da preservare).

Lo stato storicizzato **esiste già ed è popolato** (design 2026-06-26): `classi`
con `anno_scolastico`/`stato`/`*_origine`, `adozioni` con
`anno_scolastico`/`codicescuola`, indicizzati. Per bacherini oggi:
`classi` 202526=37.775 / 202627=77.453; `adozioni` 202526=370.597 /
202627=293.828. È proprio la promozione per-scuola a produrre il 202627.

## Obiettivo

Riconoscere due esperienze distinte sullo **stesso** account editore, guidate
dalla membership, e sostituire il fan-out con un builder set-based:

- **Editore-admin** → **analytics + assegnazione** (aggregati veloci, niente
  lista 16k, niente "promuovi tutte" nazionale).
- **Agente** (member) → `controllo_adozioni` **operativa** attuale, scopata da
  `Current.scuole = membership.scuole` (sottoinsieme → veloce per costruzione);
  promozione "attenta" per-scuola solo qui, negli anni successivi.

## Sezione 1 — Ruoli e scoping

Infrastruttura già presente e coerente:

- `Current.scuole`: **admin/owner → `account.scuole`**, **member →
  `membership.scuole`** (via `membership_scuole`, indice unico
  `(membership_id, scuola_id)`).
- concern `Accounts::Membership::ScuoleAssegnabili` (`assegna`/`revoca`).
- controller `accounts/members/membership_scuole_controller`.

**Partizione:** 1 plesso/scuola singola → esattamente 1 agente. La **direzione**
(record scuola) può stare in ≥1 membership quando i suoi plessi sono divisi tra
agenti — lo schema lo consente, nessuna modifica.

Fork in `ControlloAdozioniController#index`:
`Current.admin?` → dashboard analytics/assegnazione; altrimenti vista operativa
(già scopata da `Current.scuole`).

## Sezione 2 — Builder reconcile idempotente (PRIORITÀ / questo piano)

Sostituisce il fan-out da 16k con **poche query set-based**, **idempotenti e
ri-eseguibili**, scopate **per provincia** (limita lock/memoria; robusto al
rilascio MIUR cumulativo — si rilancia man mano che arrivano le regioni).

Materializza **entrambe le annate** con la struttura attuale (`Classe` durevole,
`Adozione` snapshot):

- **202526** ← `import_scuole` / `import_adozioni` (storico stabile) →
  classi `stato: archiviata`.
- **202627** ← `new_scuole` / `new_adozioni` (corrente) →
  classi `stato: attiva`.

**Modalità: reconcile (B), non wipe.** Per ogni provincia e anno:

1. **Scuole (anagrafe)**: `upsert_all` da sorgente (direzioni prima, poi plessi;
   `unique_by [account_id, codice_ministeriale]`). Già idempotente.
2. **Classi**: `INSERT ... SELECT DISTINCT [codicescuola, annocorso, sezioneanno,
   combinazione]` dalla sorgente `ON CONFLICT DO NOTHING` (unique parziale sulle
   attive per il corrente; le archiviate 202526 hanno indice separato per anno).
   Reconcile: classi **attive** del corrente non più nella sorgente →
   `stato: archiviata`.
3. **Adozioni**: `INSERT ... SELECT` con `anno_scolastico` + `codicescuola`,
   match classe su `[codicescuola, anno_corso, sezione, combinazione]`,
   `ON CONFLICT (classe_id, codice_isbn, anno_scolastico) DO NOTHING`.
   Reconcile: adozioni **di quell'anno** assenti dalla sorgente → `DELETE`.
4. **Counter** set-based finale (riusa `update_counters` di
   `UpdateScuolaMieAdozioniJob`, scopato ai `scuola_ids` della provincia) +
   `mia`/`disdetta`.

**Job:** `ReconcileAdozioniJob(account, provincia:, anno:)` in coda `bulk`, uno
per provincia (decine di job, non 16k). Idempotente → se interrotto si rilancia.
Un orchestratore `ReconcileAccountJob(account)` fa fan-out per provincia ×
{202526, 202627}. Rimpiazza `PromuoviScuolePromuovibiliJob` per il caso editore.

**Reinventa dove serve** rispetto a `ImportScuolePerZonaJob`: quello fa
`insert_all` non-reconcile e legge solo l'anno vecchio; il builder nuovo è
idempotente, bi-sorgente e con fase di archiviazione/delete degli orfani.

**Mappature sorgenti** (colonne):
- `ImportAdozione`: `CODICESCUOLA, ANNOCORSO, SEZIONEANNO, COMBINAZIONE,
  CODICEISBN, DAACQUIST, NUOVAADOZ, CONSIGLIATO, PREZZO, TITOLO, EDITORE, ...`
  (uppercase). `anno_scolastico` stampato = `"202526"`.
- `NewAdozione`: `codicescuola, annocorso, sezioneanno, combinazione, codiceisbn,
  daacquist ILIKE 'S%', ...` (lowercase). `anno_scolastico` = `"202627"`.

**Produzione:** deve girare in prod. Batch per provincia in transazione bounded;
`ANALYZE` (non `VACUUM FULL`, shm 64MB) dopo i grossi insert; rieseguibile.

## Sezione 3 — Assegnazione agli agenti (riusa Zone/Mandati/Colleghi)

L'utente ha già un sistema per account multi-utente (Zone, Mandati, Colleghi).
Nel caso editore le cose sono diverse ma **riutilizzabili**:

- **Per provincia** (comune): assegna tutte le scuole della provincia a un
  agente (membership). Partizione → sposta da eventuale agente precedente.
- **Per lista codici** (eccezioni / provincia divisa): incolla codici → assegna.
- Scrive `membership_scuole` via `ScuoleAssegnabili`. Direzione → entrambe le
  membership quando i plessi sono divisi.

Dettaglio da definire in un piano successivo, adattando l'infrastruttura Zone/
Mandati/Colleghi esistente.

## Sezione 4 — Fork per ruolo + dashboard admin

**FATTA 2026-07-02** — piano e dettagli in
`docs/plans/2026-07-02-controllo-adozioni-dashboard.md`.

- `ControlloAdozioniController#index`: admin senza `provincia` →
  `ControlloAdozioni::Dashboard` (una query GROUP BY: totali + per provincia +
  agenti/non assegnate), `render :dashboard`; member o admin con `?provincia=`
  → vista operativa (`Panoramica`) scoped.
- Le azioni bulk (`promuovi_tutte`, `aggiorna_cambi_codice`) sono scoped per
  provincia dal drill-down; niente più bottoni nazionali nella dashboard.
- Misurato su Giunti-Bacherini (24.325 scuole): dashboard 0,49s a freddo vs
  ~5s della vecchia pagina.
- Lo strumento di assegnazione dalla tabella agenti resta per la Sezione 3.

## Rollout in produzione (ordine)

1. **Sezione 2 — `ReconcileAdozioniJob`** set-based → spegne subito il fan-out
   da 16k (fix immediato coda/calore). ← *questo piano*
2. **Sezione 4 — fork admin/agente** (pagina admin non renderizza più 16k).
3. **Sezione 3 — assegnazione** per provincia + lista codici.

## Cosa NON è in questo piano

- Unificazione tabelle MIUR (`new_/import_/old_`): resta lo swing + blue-green.
- Refactor `Stats::AdozioniQuery` / matview rollup.
- La promozione "attenta" per-scuola (`promuovi_primaria!`): resta per gli agenti
  negli anni successivi, invariata.

## Ottimizzazione già applicata (2026-07-02)

`ControlloAdozioni::Panoramica#build_cambi_codice`: memoizzata
`codici_con_adoz_per_tg(tg)` — la distinct nazionale per grado non si ripete più
una volta per zona (`cambi_codice` 3.3s → ~2.4s). Vittoria pura, resta utile per
la vista agente.
