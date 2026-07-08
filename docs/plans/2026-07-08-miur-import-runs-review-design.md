# MIUR Import Runs — revisione pagina (account-scoped) — design

**Data:** 2026-07-08
**Stato:** design validato, implementazione da fare
**Contesto:** segue e affina `2026-07-08-miur-import-diff-design.md` (feature già implementata e
collaudata in dev, run #8: +1329, 734 scuole esistenti). Qui si rivede **solo la pagina**
`miur/import_runs`, non il motore di diff.

## Problema

La pagina attuale mostra il diff **MIUR-globale**: la show del run #8 elenca tutte le 734
scuole toccate a livello nazionale. Due difetti:

1. **Volume/rumore.** 734 righe in un colpo, non navigabili né rilevanti per il singolo utente.
2. **Churn ingannevole.** Gran parte delle "rettifiche" non è sostituzione di libri ma
   **ri-codifica di `sezioneanno`** dal MIUR (es. `1A` → `1AAFM` con l'indirizzo). Siccome
   `sezioneanno` fa parte della class-key, ogni riga esce come rimossa (vecchio codice) +
   aggiunta (nuovo) → numeri gonfiati. Es. `BTTD32000N`: `+1095/−1095`, interamente re-keying.

## Principio guida

Il **motore di diff resta MIUR-globale** (dati calcolati una volta, corretti). Cambia solo la
**lettura**: la pagina riguarda **esclusivamente le scuole dell'account**.

Con lo scoping il volume si sgonfia da sé (dati reali, run #8):

| Tipo account | Esempio | Scuole nel diff |
|---|---|---|
| Rappresentante | "Tassi" 110 scuole | 3 (+11/−11) |
| Rappresentante | "polso" 18 scuole | 3 (+13/−17) |
| Editore | "zanichelli" 3990 scuole | 40 (+488/−311) |
| Editore | "Giunti" 24340 scuole | 295 (+696/−564) |

Un rappresentante vede 1–6 scuole: la pagina diventa immediatamente operativa.

## Blocco 1 — Scoping all'account

**Aggancio dati:** `miur_import_diff_scuole.codicescuola` ↔ `scuole.codice_ministeriale`
filtrato per l'account. Pattern benedetto (memoria progetto): `Scuola.where(account_id:
Current.account.id)`, mai `user_scuole`. Codici precaricati una volta e riusati:

```ruby
account_codici = Scuola.where(account_id: Current.account.id)
                       .where.not(codice_ministeriale: [nil, ""]).pluck(:codice_ministeriale)
```

- **Index:** mostra **solo i run che toccano tue scuole** (un run con diff vuoto, o che non
  intercetta nessun tuo codice, **sparisce dalla lista**). Per riga: data, *N tue scuole
  toccate*, *+/− righe* dal rollup `diff_scuole` (query leggera).
- **Show:** base = `diff_scuole ∩ tue scuole`. Le categorie diventano *tue* esistenti/nuove/sparite.
  Denominazione **vera** (`scuola.denominazione`) con link alla scheda
  `controllo_adozioni/:codicescuola`, non il codice ministeriale nudo.

## Blocco 2 — Veri cambi vs spostamenti (re-keying)

Euristica **a lettura** (nessuna persistenza nuova), per singola scuola:

- ISBN presente **sia** tra i `+` **sia** tra i `−` → **spostamento** (libro invariato, cambia
  solo il codice classe/sezione: rumore MIUR, nessuna azione).
- ISBN **solo** tra i `+` → **vera aggiunta**.
- ISBN **solo** tra i `−` → **vera rimozione**.

Ogni scuola espone quindi tre numeri onesti: *aggiunti / rimossi / spostati*. Per una scuola
`+1095/−1095` tutta re-keying → veri cambi ≈ 0, spostamenti = 1095: a colpo d'occhio sai che
non devi fare nulla.

Costo trascurabile: gli ISBN di una scuola (già scoped) sono pochi, la classificazione è un
`group_by` in Ruby sul dettaglio della scuola.

## Blocco 2b — Scuole già promosse = "da rettificare"

Tra le tue scuole toccate dal diff, la distinzione operativa chiave è lo **stato di
promozione** (regola canonica, riusata senza duplicare: `ControlloAdozioni::Classificazione#promossa`
= classi attive con `anno_scolastico >= anno`):

- **Già promossa** → le sue `classi`/`adozioni` materializzate ora **divergono** dal nuovo
  snapshot MIUR: badge **"da rettificare"** (warning) sulla riga, e l'azione adeguata è il
  **reconcile** (bottone fan-out, vedi Blocco 3). Vale anche per i soli spostamenti: il
  re-keying delle sezioni cambia le classi materializzate.
- **Non promossa** → nessun allarme: alla promozione prenderà direttamente i dati nuovi.
  Riga informativa, nessun badge.

Il bottone "Applica le rettifiche" fa fan-out **solo sulle province delle scuole promosse
toccate** (sulle non promosse il reconcile non ha nulla da riallineare: la promozione resta
compito di `promuovi_primaria!`, mai del Reconciler — decisione già chiusa nel design MIUR sync).

## Blocco 3 — Layout e azioni

Stile `ca-*`/Fizzy.

**Index** (lista corta, più recente in cima):
> **8 lug** · 4 tue scuole · **+3 / −2** righe · *apri →*

**Show**, tre livelli:

1. **Card di sintesi:** "Rettifiche alle tue scuole · 8 lug" → N scuole, **veri cambi +X/−Y**,
   chip grigio "Z spostamenti" (segnale, non allarme).
2. **Lista tue scuole**, ordinata per **promosse prima** (sono le "da rettificare"), poi
   *veri cambi* desc:
   > **I.C. Leonardo da Vinci** · MODENA · Primaria · `da rettificare` — **+2 / −1** · ~~4 spostamenti~~
   >
   > **I.C. Bologna Centro** · BOLOGNA · Primaria — **+1 / −0** · *(non promossa: si allineerà alla promozione)*
3. **Drill scuola in linea** (`<details>/<summary>` nativi, niente Stimulus; dati pochi,
   pre-renderizzati collassati):
   - **Aggiunti** (verde) — classe · disciplina · titolo
   - **Rimossi** (rosso)
   - **▸ Spostati (N)** — **collassato di default**, espandibile ("stesso libro, altra sezione")

**Azioni operative** (entrambe manuali):
- Per scuola: **"Apri scheda"** (`controllo_adozioni/:codicescuola`, già esiste).
- **"Applica le rettifiche"**: **bottone unico con fan-out**. Il reconciler è per
  `(account, provincia, anno)`; il bottone calcola le province delle tue scuole **promosse**
  toccate e accoda un `ReconcileAdozioniJob` per ciascuna. Nessuna promossa toccata →
  notice "niente da applicare".

## Blocco 4 — Implementazione e test

**Controller** `Miur::ImportRunsController`, helper memoizzato `account_codici` riusato ovunque:
- **index:** filtra i run ai soli con `diff_scuole` fra i tuoi codici; conteggi scoped dal rollup.
- **show:** scope `diff_scuole`/`diff_righe` ai tuoi codici; classificazione righe per scuola in
  Ruby (ISBN in `+` e `−` = spostato); lookup `{codice => Scuola}` per denominazione/provincia/grado/link;
  stato promossa via `Classificazione#promossa` in un'unica query sulle scuole toccate
  (`scope.where(sanitize_sql([cl.promossa("scuole"), anno:]))`), MAI una query per scuola.

**Reconcile fan-out:** `create` non prende più `provincia`; ricalcola server-side (mai fidarsi
di parametri) le province delle tue scuole **promosse** toccate dal run e accoda un job per ciascuna.

**Drill in linea:** `<details>/<summary>` nativi.

**Error/empty states:** account senza scuole nell'import → stato vuoto pulito; run inesistente →
404; admin-only invariato.

**Test** (Minitest, fixtures accounts/scuole + `create!` dei diff):
- index **nasconde** i run che non toccano tue scuole;
- show **scopa** alle tue scuole (scuola di altro account non compare);
- **classificazione**: ISBN in `+`/`−` → spostato; solo `+` → aggiunto;
- **promossa** (con classe attiva dell'anno) → badge "da rettificare"; non promossa → no badge;
- reconcile **fan-out**: un job per ciascuna provincia con scuole **promosse** toccate
  (provincia con sole non-promosse esclusa).

## Decisioni chiuse (validate con l'utente)

1. Pagina **account-scoped** sempre (nessuna vista globale). [Blocco 1]
2. Run senza tue scuole: **nascosti** dall'index. [Blocco 1]
3. Spostamenti (re-keying): **nascosti di default, segnalati con conteggio, espandibili**. [Blocco 2/3]
4. Drill scuola **in linea**, non pagina dedicata. [Blocco 3]
5. Reconcile: **bottone unico con fan-out** sulle province, non uno per provincia. [Blocco 3]
6. Scuole **già promosse** toccate dal diff: badge **"da rettificare"** + azione reconcile;
   il fan-out copre solo le loro province. Le non promosse restano informative. [Blocco 2b]

## Fuori scope (YAGNI)

- Vista globale non-scoped / toggle admin globale-vs-account.
- Persistenza della classificazione spostamenti (resta derivata a lettura).
- Distinzione veri-cambi/spostamenti nell'**index** (solo nella show).
- Re-reconcile automatico (invariato: sempre manuale).
