# Controllo adozioni scuola primaria — Design

**Data:** 2026-06-17
**Stato:** design approvato, da trasformare in piano di implementazione
**Ambito:** verifica di correttezza delle adozioni della scuola primaria (EE) sul dataset MIUR `new_adozioni`

## Obiettivo

Costruire una procedura che, dopo ogni import MIUR, analizzi **classe per classe** le adozioni
della scuola primaria e segnali agli utenti eventuali discrepanze: prezzi sbagliati, discipline
obbligatorie mancanti, doppioni, sforamenti del tetto di spesa e scuole orfane.

L'output è una **pagina UI** per navigare *classifica → scuola → classe → anomalie*, con i dati
**precalcolati** (approccio B): un batch materializza le anomalie in tabella dopo l'import, la UI
legge soltanto.

## Dato di partenza

- Universo: `new_adozioni` con `tipogradoscuola = 'EE'` (~469k righe). **Nota:** `new_adozioni.anno_scolastico`
  è attualmente `NULL`; la tabella viene rimpiazzata in blocco a ogni import (blue-green), quindi
  "corrente" = tutte le righe EE, senza filtro anno. `new_scuole.anno_scolastico` usa il formato
  `"202526"`, `prezzi_ministeriali` usa `"2025/2026"` → il join a `new_scuole` avviene solo per codice
  (`codicescuola = codice_scuola`), quello a `PrezzoMinisteriale` sull'anno corrente di PM.
- **Classe** = chiave `(anno_scolastico, codicescuola, annocorso, sezioneanno, combinazione)`
  (è già l'indice unico `index_new_adozioni_on_classe`).
- I prezzi in `new_adozioni.prezzo` sono stringhe `"12,34"` → parsing
  `ROUND(REPLACE(prezzo, ',', '.')::numeric * 100)` con guardia regex `^\d+(\.\d+)?$`
  (stesso pattern di `PrezzoMinisteriale.popola_da_import_adozioni!`).
- I controlli su **tetto** e **discipline mancanti** considerano solo i libri **da acquistare**
  (`daacquist`); i consigliati sono esclusi. La religione in 2ª/3ª/5ª ha già `daacquist = No`
  (libro pluriennale, vedi task `cambia_religione`), quindi non è attesa in quelle classi.

## Riferimenti

### Esistenti — `PrezzoMinisteriale`
- Prezzo dominante per `(anno_scolastico, classe = annocorso, disciplina)` (solo discipline con
  prezzo dominante > 90%).
- `discipline_per_classe` → discipline presenti in tabella per classe.
- Usato per il check `prezzo_disciplina` e come base prezzi del tetto.

### Nuovo — prezzo modale per ISBN
Riferimento `codiceisbn → prezzo_cents, freq, totale` calcolato sull'universo EE corrente, usato dal
check `prezzo_isbn` (lo stesso libro deve costare uguale ovunque). Non serve una tabella persistente
dedicata: si calcola come CTE all'interno del batch di rebuild. Si considerano solo gli ISBN con
dominanza alta (`totale >= 50` e `freq::float / totale > 0.9`) per evitare falsi positivi su libri
con prezzi legittimamente variabili.

## Modello a requisiti (discipline obbligatorie)

Le obbligatorie sono espresse come **requisiti**, ognuno soddisfabile da discipline alternative (OR).
Un requisito è soddisfatto se nella classe esiste almeno un libro `daacquist` con una delle sue
discipline.

Definizioni dei requisiti (match per stringa esatta o `LIKE`):

- `LIBRO_PRIMA_CLASSE` = `IL LIBRO DELLA PRIMA CLASSE`
- `INGLESE` = `LINGUA INGLESE`
- `RELIGIONE_ALT` = `disciplina ILIKE 'RELIGIONE%' OR disciplina ILIKE 'ADOZIONE ALTERNATIVA%'`
  (la stringa MIUR dell'alternativa è `ADOZIONE ALTERNATIVA ART. 156 D.L. 297/94`, anche con spazio finale — vedi task `cambia_religione`)
- `SUSSIDIARIO_1BIENNIO` = `SUSSIDIARIO (1° BIENNIO)`
- `SUSSIDIARIO_LINGUAGGI` = `SUSSIDIARIO DEI LINGUAGGI`
- `SUSSIDIARIO_DISCIPLINE` = soddisfatto da `SUSSIDIARIO DELLE DISCIPLINE` (volume unico) **oppure**
  dalla coppia coordinata (`...(AMBITO ANTROPOLOGICO)` **e** `...(AMBITO SCIENTIFICO)`)

Set curato per classe:

| Classe | Requisiti |
|--------|-----------|
| 1 | LIBRO_PRIMA_CLASSE · INGLESE · RELIGIONE_ALT |
| 2 | SUSSIDIARIO_1BIENNIO · INGLESE |
| 3 | SUSSIDIARIO_1BIENNIO · INGLESE |
| 4 | SUSSIDIARIO_LINGUAGGI · SUSSIDIARIO_DISCIPLINE · INGLESE · RELIGIONE_ALT |
| 5 | SUSSIDIARIO_LINGUAGGI · SUSSIDIARIO_DISCIPLINE · INGLESE |

Note di curatura:
- `IL LIBRO DELLA PRIMA CLASSE` compare in `PrezzoMinisteriale` anche per la 2ª ma è escluso dai
  requisiti della 2ª (uso pluriennale / refusi).
- `RELIGIONE_ALT` è obbligatoria solo in 1ª e 4ª (coerente con `daacquist = No` in 2ª/3ª/5ª).

Il modello requisiti vive in una **costante/configurazione Ruby** (es. `ControlloAdozioni::REQUISITI`),
non in tabella, perché incorpora logica di dominio (OR sussidiario, religione/alt).

## I 6 controlli

| # | Tipo | Grano | Logica |
|---|------|-------|--------|
| 1 | `prezzo_isbn` | riga/libro | `prezzo_cents <> modale_isbn`, su ISBN a dominanza alta. **Esclude** righe `RELIGIONE_ALT`. |
| 2 | `prezzo_disciplina` | riga/libro | `prezzo_cents <> PrezzoMinisteriale(annocorso, disciplina)`, solo discipline presenti in PM. |
| 3 | `disciplina_mancante` | classe | requisito della classe non soddisfatto da alcun libro `daacquist` (modello a requisiti, con OR). Una anomalia per requisito mancante. |
| 4 | `doppione` | classe·disciplina | `COUNT(DISTINCT titolo+editore) > 1` per `(classe, disciplina)`, **ignorando i volumi** dello stesso titolo. **Esclude** `RELIGIONE_ALT` (religione + alternativa convivono legittimamente). |
| 5 | `tetto_superato` | classe | somma prezzi libri `daacquist` della classe > tetto. Tetto = somma di **un** prezzo di riferimento per requisito (per `SUSSIDIARIO_DISCIPLINE`: prezzo dell'unico, per evitare doppio conteggio coppia). |
| 6 | `scuola_mancante` | codicescuola | `codicescuola` in `new_adozioni` (EE) ma assente in `new_scuole`: adozioni orfane, spia di import incompleto. |

Tutti i controlli sono **set-based SQL** (`INSERT … SELECT`); nessun ciclo Ruby per riga (universo ~milioni di righe).

## Tabella anomalie

Tabella unica `controllo_anomalie`, una riga per anomalia, con campi scuola **denormalizzati** (da
`new_scuole`) per filtrare la classifica nazionale senza join:

```
id
anno_scolastico
codicescuola
annocorso  sezioneanno  combinazione      -- identità classe (null per scuola_mancante)
regione  provincia  comune  denominazione -- denorm da new_scuole (null se scuola_mancante)
tipo                                       -- prezzo_isbn|prezzo_disciplina|disciplina_mancante|doppione|tetto_superato|scuola_mancante
disciplina                                 -- nullable
codiceisbn  titolo  editore                -- nullable (check su libro)
prezzo_cents  prezzo_atteso_cents  delta_cents  -- nullable
dettaglio jsonb                            -- extra (es. requisito, lista isbn doppione, conteggi)
created_at
```

Indici: `(anno_scolastico, codicescuola)`, `codicescuola`, `tipo`, `provincia`.
Overview / classifica = `GROUP BY codicescuola` con conteggi (per tipo).

> Alternativa valutata e scartata per v1: due tabelle (`controllo_classi` riepilogo +
> `controllo_anomalie` dettaglio). Più normalizzata, ma per v1 la tabella unica + aggregazioni
> on-the-fly per l'overview è sufficiente e più semplice da rigenerare.

## Rebuild

- Tutta l'analisi è una sequenza di `INSERT … SELECT` su una tabella di staging
  `controllo_anomalie_stg`, seguita da **swap atomico** (`DROP` + `RENAME` in transazione, lock
  `ACCESS EXCLUSIVE` di millisecondi) — stesso pattern blue-green di `import:new_adozioni`. Le letture
  della UI non vengono bloccate; un crash prima dello swap lascia la tabella live intatta.
- Esposto come task rake `controllo_adozioni:rebuild`, **agganciato a fine** `import:new_adozioni`
  (dopo `cambia_religione`), e lanciabile standalone.
- `ANALYZE controllo_anomalie` dopo lo swap (no `VACUUM FULL`: shm 64MB sul container db).

## UI

Controller read-only `ControlloAdozioniController` (rotte sotto `/controllo_adozioni` o namespace
analogo):

- **`index` (classifica)**: scuole ordinate per n° anomalie, con conteggi per tipo; filtri
  `regione`, `provincia`, `tipo`. Default: scuole dell'account (JOIN `scuole` su codice ministeriale +
  `account_id`); toggle/ricerca per estendere a tutta Italia (codice, comune, provincia).
- **`show` (scuola)**: una scuola, le sue classi con badge delle anomalie per classe; in testa le
  anomalie `scuola_mancante` se presenti.
- **classe (dettaglio)**: elenco anomalie della classe, con libro/disciplina/prezzo/atteso/delta.

Pattern visuali da **Fizzy** (liste, filtri, badge, card). Solo lettura: nessuna mutazione del dato MIUR.

"Segnalare agli utenti" = visualizzazione in pagina (badge/elenco) per v1. Notifiche/email: fuori scope.

## Modelli / file previsti (orientativo, dettagli nel piano)

- `db/migrate/…_create_controllo_anomalie.rb`
- `app/models/controllo_anomalia.rb` (read-mostly; scopi per tipo, per scuola, classifica)
- `app/models/controllo_adozioni.rb` o `lib/controllo_adozioni/` — costante `REQUISITI` + orchestrazione SQL del rebuild
- `lib/tasks/controllo_adozioni.rake` — task `rebuild`, hook in `import.rake`
- `app/controllers/controllo_adozioni_controller.rb` + viste `index`/`show`
- Test: modello (parsing prezzo, requisiti OR, esclusione religione/alt), e un test del rebuild su
  fixture `new_adozioni`/`new_scuole` che verifichi ciascun tipo di anomalia.

## Decisioni confermate

- Dato: `new_adozioni` EE, anno corrente.
- 6 controlli come sopra; tutti set-based SQL.
- `daacquist` sì (consigliati esclusi) per tetto e mancanti.
- Discipline obbligatorie = set curato a **requisiti** (OR), non tutte quelle in PM.
- Doppione ignora i volumi dello stesso titolo; esclude religione/alternativa.
- Religione/alternativa esclusa dai check prezzo (1) e doppione (4); obbligatoria solo in 1ª e 4ª.
- Tetto = somma prezzi ministeriali, un riferimento per requisito.
- Output: tabella precalcolata + UI classifica/scuola/classe; default account + ricerca nazionale.

## Fuori scope (v1)

- Notifiche/email automatiche delle anomalie.
- Tetto di spesa di legge ufficiale (si usa la somma dei prezzi di riferimento).
- Controlli su ordini di grado diversi da EE.
- Azioni di correzione del dato dalla UI.
