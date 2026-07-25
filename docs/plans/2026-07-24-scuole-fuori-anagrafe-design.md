# Scuole fuori anagrafe MIUR — cambio codice, soppresse, gestione manuale

Data: 2026-07-24. Stato: design validato con Paolo, da pianificare.

## Problema

Al passaggio anno alcune scuole attive dell'account spariscono dall'anagrafe MIUR
(`miur_scuole`) del nuovo anno e il flusso attuale non le vede:

- `Scuola#promuovibile?` richiede codice in `miur_scuole` **e** righe EE in
  `miur_adozioni` → falso col vecchio codice.
- `ControlloAdozioni::Classificazione::SQL_CLASSIFICA` richiede `EXISTS miur_adozioni`
  anche per i codici nuovi candidati → un successore presente solo in anagrafe
  (es. REEE85006A) è invisibile.

Risultato: limbo. Classi e adozioni dell'anno vecchio restano attive e gonfiano
i contatori (`scuole.adozioni_count`, `libri.adozioni_count`).

Caso scatenante (account Real Tassi): MARCO POLO primaria RE, `REEE849022` →
`REEE85006A` (dall'IC Pertini 2 soppresso all'IC Pertini 1). Inoltre le adozioni
MIUR per il nuovo codice potrebbero **non arrivare mai**: il design non può
aspettare il roster.

## Tre categorie

Una scuola attiva col codice assente da `miur_scuole` dell'anno corrente e non
ancora promossa è:

1. **Cambio codice probabile** — esiste un candidato successore in anagrafe:
   match su comune + natura (paritaria sì/no) + denominazione simile
   (`denom_norm`/`denom_simili?` esistenti), **senza richiedere `miur_adozioni`**.
2. **Soppressa** — nessun candidato: scuola chiusa o a esaurimento. Le sezioni
   adottate NON devono più essere conteggiate.
3. **Gestione manuale** — scuole mai esistite nel MIUR ma reali per l'account
   (es. `Rexxravone`, Lola Sacchetti di Sant'Ilario), con classi e adozioni
   comunicate per altri canali. Nuovo flag `scuole.gestione_manuale`
   (boolean, default false). Una volta marcata: esce dal bucket per sempre,
   le adozioni continuano a contare, è esclusa da promozione/classificazione
   MIUR e avanza d'anno con la promozione cieca.

Le orfane EE ancora in anagrafe ma senza adozioni (Marconi, S. Agostino, …)
restano fuori: si sbloccano da sole quando il MIUR pubblica.

## Le azioni

### a) Aggiorna codice

Riusa il meccanismo di `AggiornaCambiCodiceJob` (aggiorna_cambi_codice_job.rb:24-27):
`update!(codice_ministeriale: nuovo, note: "ex codice …")` + `ScuolaPromuoviClassiJob`.
Se `miur_adozioni` per il nuovo codice esistono la promozione normale fa tutto;
altrimenti la scuola resta col codice nuovo e diventa promuovibile alla cieca
(azione c), oppure si sblocca da sola al run MIUR successivo.

Candidato unico → azione diretta. Più candidati → scelta in dialog.

### b) Archivia soppressa

- Classi attive → `stato: "archiviata"` (stesso tombstone della 5ª diplomata).
- Scuola → `stato: "archiviata"`.
- Ricalcolo contatori: `UpdateScuolaMieAdozioniJob` (scuola) +
  `UpdateMieAdozioniJob` (sgonfia `libri.adozioni_count`).

Tutto resta consultabile come storico.

### c) Promozione cieca

Per scuole senza roster MIUR: codice appena aggiornato senza adozioni pubblicate,
oppure gestione manuale. Le classi scorrono come in `promuovi_primaria!`
(stesso record → documenti non orfanati), ma senza roster:

- **5ª** → archiviata.
- **Avanzano in 2ª, 3ª, 5ª**: le adozioni dell'anno precedente scorrono col
  **prosegui** (v. sotto). Se `adozione.libro.prosegue_in` esiste → nuova riga
  con ISBN/titolo/prezzo/libro_id del volume successivo. Se il link manca o la
  riga non ha `libro_id` → riporto della riga com'è. In entrambi i casi la riga
  nuova è flaggata `riportata: true` (colonna nuova su `adozioni`): provvisoria,
  riconoscibile per sistemazione a mano o riallineamento MIUR futuro.
- **Avanzano in 4ª / nuove 1ª**: nessuna adozione (anni di nuova adozione).
- **Nuove 1ª**: create con le stesse sezioni delle 1ª dell'anno precedente
  (quelle appena avanzate in 2ª), vuote.

Prima dell'esecuzione: anteprima (pattern `controllo_adozioni/anteprima`) con
classi che scorrono, adozioni che proseguono col volume successivo, righe
riportate uguali, 1ª ricreate vuote, 5ª archiviate. Conferma → job.

## Prosegui dei libri

Nuova colonna self-referenziale `libri.prosegue_in_id` (bigint, no FK):
"questo libro prosegue in quest'altro" (Banda Bus 1 → Banda Bus 2), con inverso
`has_one :precedente`.

- **Compilazione assistita** (regola corretta 2026-07-24, la collana NON si usa):
  candidati inferiti da stessa **categoria** + **classe + 1** + stesso
  **titolo-base** (titolo senza numero di volume in coda) + stessa **disciplina**
  ministeriale, con l'eccezione del primo biennio: IL LIBRO DELLA PRIMA CLASSE
  scorre nel SUSSIDIARIO (1° BIENNIO) — dominio confermato da prezzi_ministeriali.
  Task/azione "collega prosegui" applica i match univoci; select "prosegue in"
  nella edit inline del libro (container/_edit_form) per casi ambigui.
- Utile oltre questo design: previsioni copie, scorrimenti 235.

## Rilevazione e classificazione

In `ControlloAdozioni::Panoramica` + `Classificazione`, nuovo predicato
**fuori_anagrafe**: scuola attiva, `codice_ministeriale` assente da
`miur_scuole` dell'anno, non promossa, `gestione_manuale = false`.
Il matching candidati riusa `denom_norm`/`denom_simili?` ma dal lato scuole
dell'account e sul solo `miur_scuole` (niente vincolo `miur_adozioni`).

## UI

### Passaggio anno (Controllo Adozioni index)

Nuovo **step 5 "Fuori anagrafe"** dopo Anomalie. Contatore = scuole fuori
anagrafe. `job: nil`, niente bulk: ogni scuola richiede una decisione umana.

### Drill-down provincia (righe Panoramica)

Badge **"fuori anagrafe"** sulla riga, con:
- candidato unico → bottone "Aggiorna codice → <codice>" (con denominazione);
- più candidati → dialog di scelta;
- menu con "Archivia (soppressa)" (con conferma) e "Segna come gestione manuale".

### Show controllo adozioni (`controllo_adozioni#show`) — POSTO DI LAVORO

La scheda scuola del controllo è dove si lavora la scuola fuori anagrafe,
con restyling:

- Header a pattern `content_for :header`: torna (`back_link_to`) in
  `header__actions--start`, azioni in `header__actions--end`, titolo centrale.
- Pulsante "Passaggio anno" **nascosto se la scuola è già promossa**.
- Pulsanti anteprima più rettangolari (non `btn--small` in un `<p>` sparso),
  con **segnalazione quando manca l'elenco adozioni** per quell'anno.
- Per le scuole fuori anagrafe: blocco con le tre azioni (aggiorna codice /
  archivia soppressa / gestione manuale) e, quando applicabile, promozione
  cieca con anteprima.

### Show scuola (`scuole#show`)

Banner in testa quando attiva e fuori anagrafe: "Il codice <vecchio> non è più
nell'anagrafe MIUR <anno> — cambio codice o soppressione", con candidato se
c'è e link alla scheda controllo. Per gestione manuale: nessun allarme, badge
discreto "gestione manuale" vicino al codice.

## Schema — modifiche

| Tabella  | Modifica |
|----------|----------|
| scuole   | `gestione_manuale :boolean, default: false, null: false` |
| libri    | `prosegue_in_id :bigint` (self-ref, no FK) + index |
| adozioni | `riportata :boolean, default: false, null: false` |

## Rifiniture dal collaudo (2026-07-24, con Paolo su Marco Polo dev)

- **Prosegui**: `titolo_base` normalizza punteggiatura e rimuove i numeri di
  volume 1-2 cifre OVUNQUE nel titolo (nei dati reali stanno in mezzo:
  "BANDA DEL BUS 1 MATEMATICA"); le annate a 4 cifre restano. La select usa
  `Libro#opzioni_prosegui`: categoria + classe+1 ordinate per somiglianza di
  titolo — niente filtri duri su disciplina (deriva: LETTURE → ITALIANO).
- **Riporto cieco**: pluriennali (RELIGIONE/ALTERNATIV) → `da_acquistare: No`
  verso 2ª/3ª/5ª. Verso la 4ª non scorre NIENTE (nemmeno inglese: i corsi si
  fermano in 3ª).
- **Stato MIUR sulla scuola**: `Scuola#fuori_anagrafe_miur?` (esclude promosse)
  e `#in_attesa_roster_miur?` (NON esclude promosse: l'elenco manca finché il
  MIUR non pubblica, il segnale resta). Badge nella sezione adozioni, sotto il
  divider centrato "Mie adozioni | Tutte", con link al controllo.
- **Aggiungi adozione manuale sulla classe**: modal dalla sezione adozioni
  (select classe + picker libro + flag), per 1ª/4ª note a Paolo su scuole
  manuali/promosse ciecamente.
- Il gate della promozione cieca è l'assenza del roster
  (`Scheda#promozione_cieca_possibile?`), non fuori_anagrafe/manuale: copre il
  codice appena aggiornato con adozioni mai pubblicate.
- **Prosegui per la concorrenza** (`Miur::VolumeSuccessivo`): il prosegui su
  Libro copre solo il catalogo proprio; le adozioni concorrenza (libro_id nil)
  risolvono il volume successivo dai `miur_adozioni` NAZIONALI dell'anno target
  — stesso editore + titolo-base + disciplina compatibile (stessa eccezione
  biennio), annocorso+1, ISBN a maggioranza stretta fra i roster delle altre
  scuole; pareggio o zero candidati → copia identica. Priorità nel riporto:
  prosegue_in esplicito → risoluzione MIUR → copia identica.

## Censimento Real Tassi (riferimento, 2026-07-23 prod)

- Marco Polo `REEE849022` → candidato certo `REEE85006A` (cambio codice)
- IC Pertini 2 `REIC84900V` soppresso, 0 classi (archivia)
- `Rexxravone`, `rexxlola` → gestione manuale
- Marconi, S. Agostino, Steiner, IES, D.D. Correggio: in anagrafe senza
  adozioni → si sbloccano da sole, fuori scope
