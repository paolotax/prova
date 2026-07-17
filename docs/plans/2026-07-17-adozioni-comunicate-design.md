# Adozioni comunicate dagli editori — design

**Data**: 2026-07-17
**Stato**: validato, da implementare

## Problema

Gli editori mandano la loro versione delle adozioni con il numero di alunni per
classe/sezione: alcuni in Excel (es. Giunti — una riga per sezione), altri in PDF
(es. TREDIECI — sezioni raggruppate, "5 A,B,C → 69 alunni totali"). Serve:

1. controllare che le adozioni comunicate corrispondano alle proprie
2. riportare il numero di alunni su `classi.numero_alunni`

La procedura 2025/26 (`AdozioneComunicata` top-level + controller/view eliminati in
bb53eda4) è da rifare: matchava contro `Miur::Adozione` salvando `import_adozione_id`
(gli id MIUR cambiano ad ogni reimport blue-green), anno hardcoded "202526",
tabella bigint + `user_id` fuori convenzione.

## Riga canonica

Entrambi i formati convergono su:

```
codicescuola (meccanografico) + EAN + classe + sezione/i + alunni [+ editore, titolo]
```

L'Excel Giunti è già per-sezione; il PDF TREDIECI raggruppa
(`sezioni: "A,B,C", alunni: 69` = totale, non distribuibile con certezza).

## Namespace

Tutto sotto **`Adozioni::`** (non `Miur::`, riservato a dati/scraper ministeriali):

- Modello `Adozioni::Comunicata` → tabella `adozioni_comunicate`
  (`table_name_prefix "adozioni_"`, come `Miur::Adozione` → `miur_adozioni`)
- POROs `Adozioni::Comunicate::Importer` e `Adozioni::Comunicate::Matcher`
  (pattern `Libri::Importer` / `Clienti::Importer`)
- Il vecchio modello `AdozioneComunicata` e la sua tabella (668 righe 2025/26,
  controllo ormai consumato) si eliminano.

## Modello dati

Nuova tabella `adozioni_comunicate` (UUID, `account_id`, no FK):

| campo | tipo | note |
|---|---|---|
| `account_id` | uuid | multi-tenancy |
| `anno_scolastico` | string | es. "202627", mai hardcoded |
| `editore` | string | com'è scritto nel file |
| `fonte` | string | `excel` \| `mcp` |
| `import_record_id` | uuid | tracciabilità verso l'ImportRecord |
| `codicescuola` | string | meccanografico |
| `ean` | string | normalizzato (no trattini/spazi) |
| `titolo` | string | |
| `classe` | string | anno corso "1".."5" |
| `sezioni` | string | "A" oppure "A,B,C" (PDF raggruppati, resta com'è nel file) |
| `alunni` | integer | totale per la riga |
| `adozione_id` | uuid | match tra le PROPRIE adozioni (id stabili) |
| `classe_id` | uuid | classe matchata (solo righe mono-sezione) |
| `stato_match` | string | vedi sotto |
| `descrizione_scuola`, `comune`, `provincia` | string | denormalizzati per leggere le discrepanze senza join |

**Unicità** (re-import idempotente, aggiorna `alunni` invece di duplicare):
`account_id + anno_scolastico + codicescuola + ean + classe + sezioni`

## Matching (`Adozioni::Comunicate::Matcher`)

Per ogni riga:

1. cerca l'`Adozione` dell'account con
   `anno_scolastico + codicescuola + codice_isbn(ean) + anno_corso(classe)`
2. se mono-sezione, verifica la `Classe` (quella dell'adozione o altra della
   stessa scuola/anno con la sezione comunicata)
3. esiti (`stato_match`):
   - `matched` — salva `adozione_id` + `classe_id`
   - `classe_non_trovata` — adozione trovata, sezione comunicata inesistente tra le proprie classi
   - `adozione_non_trovata` — l'editore comunica un'adozione non presente (la discrepanza interessante)
   - `multi_sezione` — riga PDF raggruppata: adozione matchata, nessuna classe singola
   - `multi_sezione_distribuita` — vedi write-back

Il matching è **ri-eseguibile in blocco** (`Matcher.rimatch!(account:, anno:)`):
dopo aver creato adozioni/classi mancanti, le righe orfane si agganciano da sole
e il write-back completa.

## Write-back su `classi.numero_alunni`

- Righe `matched`: `classe.update(numero_alunni: alunni)` — sovrascrive sempre,
  il dato dell'editore è più fresco.
- Righe `multi_sezione`: se **tutte** le sezioni elencate esistono come proprie
  classi e nessuna ha già `numero_alunni`, distribuzione equa (69/3 = 23) con
  stato `multi_sezione_distribuita`; altrimenti restano da rivedere a mano.
  Niente invenzioni silenziose.

## Ingressi — un importer, due porte

### Excel via web UI (sistema imports unificato)

- Nuovo `import_type: "adozioni_comunicate"` su `ImportRecord`
- Form in `imports/new?type=adozioni_comunicate` accanto a libri/clienti/persone
- `ImportProcessJob` → `Adozioni::Comunicate::Importer.new(file, user, account:)`
  — Roo, header flessibili (`Classe`/`Sezione` separati o campo combinato
  "classi+sezioni", riusando la logica `split_classi_sezioni` del vecchio modello)
- A fine import: `Matcher` sulle righe caricate + write-back sui `matched`

### Tool MCP `adozioni_comunicate_import` (PDF via Claude/GPT)

- Pattern `libri_import`/`clienti_import`: `input_schema` con array di righe
  `{codicescuola, ean, titolo, classe, sezioni, alunni, editore}` + `anno_scolastico`
- Il PDF si allega in chat: il LLM estrae le righe e chiama il tool, anche a
  batch multipli. Nessun parser PDF server-side da mantenere.
- Stesso `Importer` sotto, stessa idempotenza
- La risposta riassume: importate / matched / **elenco discrepanze** (visibili già in chat)
- **Da aggiornare**: scagnozz-cli (MCP + Cobra) e le 2 copie di SKILL.md

## UI di confronto

Pagina `adozioni/comunicate` (index):

- Tabella canonica `.table` + convenzioni data-table: scuola, EAN/titolo,
  classe/sezioni, alunni, editore, stato match
- Filtri `Filters::*` + `FilterScoped`: editore, stato match, provincia
- Riepilogo in testa: X righe, Y matched (alunni scritti), Z discrepanze
- Discrepanze raggruppate per stato: `adozione_non_trovata` (creare l'adozione o
  segnalare all'editore), `classe_non_trovata`, `multi_sezione` da distribuire
- Azione "Ri-esegui matching" in blocco
- Per le `multi_sezione`: azione per riga con classi candidate e distribuzione manuale
- Niente show/edit elaborati (YAGNI): si corregge ri-importando, che è idempotente

## File di esempio

- Excel Giunti: `/home/paolotax/Downloads/Adozioni 202627 (2).xlsx`
  (header: Cod. Agente, Anno, CodMinisteriale, Descrizione, Indirizzo, CAP,
  Comune, Provincia, Cod. Sc., Editore, Ean, Titolo, Classe, Sezione, Alunni)
- PDF TREDIECI: `/home/paolotax/Downloads/Adozioni TREDIECI Reggio Emilia per scuola.pdf`
  (raggruppato per scuola, sezioni aggregate, N° alunni totale per riga)
