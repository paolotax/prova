# Magazzino: giacenze, consegne parziali, acconti — Design

**Data:** 2026-07-07
**Stato:** validato, da implementare

## Problema

La gestione magazzino ha oggi **4 implementazioni concorrenti** del calcolo giacenza,
incoerenti tra loro:

| Implementazione | Dove | Problemi |
|---|---|---|
| `Views::Giacenza` (vista Scenic) | `libri#show/edit`, badge helper | `WHERE users.id = 1` hardcoded; usa colonna legacy `documenti.status`; ignora catena padre/figli → doppi conteggi |
| `Libro::Movimenti` (PORO) | footer `libri#show` | il più moderno, ma aggrega in Ruby, nessuno scoping account, segno duplicato in `segno_per` |
| `LibroInfo` (service) | mai usato | bug (`result[0]['carichi   ']` → nil), SQL interpolato |
| `Libro.crosstab` + `LibroSituazio` | export xlsx | raw crosstab con `#{Current.user.id}`, nessuna gestione padre/figli né stati |

Incoerenze strutturali:

1. La convenzione di segno vive in 3 posti (SQL vista, `Movimenti#segno_per`,
   `CASE` in `Saldo#ricalcola!`). `Causale` non dichiara mai il proprio effetto.
2. Scoping incoerente: vista per user hardcoded, Movimenti senza scoping,
   il resto dell'app è account-scoped.
3. Righe condivise nella catena (ordine→DDT→TD01 puntano alle stesse `Riga`
   via `DocumentoRiga`): chi non filtra `documento_padre_id: nil` conta doppio.
4. Consegna e Pagamento sono `has_one` tutto-o-niente: impossibile gestire
   consegne parziali di un ordine o acconti.

Dati piccoli (~2.200 documenti, ~8k righe): il problema non è la scala ma la coerenza.

## Decisioni

- **Scoping**: giacenza **per account** (team-wide), come Saldo.
- **Contatori canonici**: disponibile (magazzino vendita), campionario,
  impegnato (ordini aperti), venduto (copie + importo).
- **Ordine aperto** = documento di vendita **non (interamente) consegnato**.
- **Scarico fisico alla consegna**: una vendita scarica il magazzino quando le
  copie vengono consegnate, non alla creazione del documento.
- **Architettura**: tabella denormalizzata `giacenze` (pattern Saldo),
  ricalcolo idempotente full-from-scratch per libro.
- **Consegne parziali**: `Consegna` diventa `has_many`, con righe
  (`consegna_righe`: documento_riga + quantità). Storia completa.
- **Pagamenti parziali**: `Pagamento` diventa `has_many` con `importo_cents`
  (acconti per importo, non per riga). Tipo di pagamento **atteso** dichiarato
  sul documento (`tipo_pagamento_previsto`), fa da default per gli acconti.
- **Cleanup completo**: eliminare implementazioni morte, unificare il segno in
  Causale, rifare l'export senza `crosstab()`, droppare colonne legacy.

## 1. Semantica unificata: il segno vive in Causale

`Causale` è l'unica fonte della semantica di magazzino. Nessuna nuova colonna:

```ruby
class Causale < ApplicationRecord
  enum :tipo_movimento, { ordine: 0, vendita: 1, carico: 2 }
  enum :movimento, { entrata: 0, uscita: 1 }
  enum :magazzino, { vendita: "vendita", campionario: "campionario" }, prefix: :magazzino

  # Effetto fisico sul magazzino: entrata carica (+1), uscita scarica (-1)
  def segno = entrata? ? 1 : -1

  # Frammento SQL unico, usato da Giacenza, Saldo e Movimenti
  SEGNO_SQL = "CASE causali.movimento WHEN 0 THEN 1 ELSE -1 END"
end
```

I contatori derivano tutti dal segno fisico:

| Contatore | Causali | Gating | Formula |
|---|---|---|---|
| `disponibile` | magazzino vendita: carichi subito, vendite alla consegna | Consegna (per riga) | carichi + Σ segno·consegnato |
| `campionario` | magazzino campionario | nessuno | Σ segno·quantità |
| `impegnato` | vendite non consegnate | — | Σ (−segno)·(quantità − consegnato) per riga |
| `venduto_copie` / `venduto_cents` | vendite consegnate | Consegna (per riga) | Σ (−segno)·consegnato e importo |

Invarianti: ogni copia caricata è disponibile, impegnata o venduta;
per riga: ordinato = consegnato + residuo, sempre.

Note di credito (TD04) e rese cliente (entrata): stessa regola, rientrano in
giacenza quando marcate consegnate (= merce fisicamente rientrata). Uniformità,
niente casi speciali.

Contano solo i documenti con `documento_padre_id: nil` (i figli condividono le
righe del padre → mai doppi conteggi, come già fa Saldo).

## 2. Tabella `giacenze` e ricalcolo idempotente

```ruby
create_table :giacenze, id: :uuid do |t|
  t.uuid    :account_id, null: false
  t.bigint  :libro_id,   null: false
  t.integer :disponibile,   default: 0, null: false
  t.integer :campionario,   default: 0, null: false
  t.integer :impegnato,     default: 0, null: false
  t.integer :venduto_copie, default: 0, null: false
  t.bigint  :venduto_cents, default: 0, null: false
  t.timestamps
end
add_index :giacenze, [:account_id, :libro_id], unique: true
```

```ruby
class Giacenza < ApplicationRecord
  include AccountScoped
  belongs_to :libro

  def ricalcola!
    # 1 query: documento_righe → righe → documenti(padre nil, account) → causali
    #          LEFT JOIN consegna_righe (consegnato per riga)
    # FILTER per i contatori usando Causale::SEGNO_SQL
  end

  # Bulk per import/backfill: INSERT ... ON CONFLICT (account_id, libro_id) DO UPDATE
  def self.ricalcola_tutte!(account)
end
```

Su `Libro`: `has_one :giacenza` (vera tabella, sostituisce la vista) e
`ricalcola_giacenza!` (crea-o-ricalcola, come `saldo!`).

Trigger — ricalcolo sempre full-from-scratch per libro (idempotente, mai drift):

| Evento | Hook | Ricalcola |
|---|---|---|
| DocumentoRiga create/destroy | `after_commit` | libro della riga |
| Riga update (quantità/prezzo/libro) | `after_commit` | libro attuale + precedente se cambiato |
| Consegna create/destroy | Consegnabile (accanto a `ricalcola_saldo_clientable`) | tutti i libri del documento |
| Documento destroy / cambio causale o padre | `after_commit` | tutti i libri del documento |

Gli importer (`DocumentiImporter`) saltano i callback per-riga e chiamano
`ricalcola_tutte!` a fine import.

## 3. Consegne parziali

```ruby
# consegne: cade l'indice unique su consegnabile → has_many
create_table :consegna_righe, id: :uuid do |t|
  t.uuid    :consegna_id,       null: false
  t.bigint  :documento_riga_id, null: false  # per-documento, non la Riga condivisa
  t.integer :quantita,          null: false
  t.timestamps
end
```

Punta a `documento_riga` (non a `Riga`, condivisa nella catena): la consegna
appartiene inequivocabilmente a un documento.

`Consegnabile` rivisto:

- `mark_consegnato` (fast path, un click come oggi) → Consegna con
  `consegna_righe` per tutti i residui
- `consegna_parziale!(quantita_per_documento_riga)` → Consegna con le righe
  indicate; valida `quantita ≤ residuo` per riga
- `consegnato?` = residuo totale zero (non più "esiste una consegna")
- `parzialmente_consegnato?` = consegne presenti ma residuo > 0 (nuovo stato UI)
- `consegnato_il` = data dell'ultima consegna
- `unmark_consegnato` → distrugge una consegna specifica, i residui riaumentano

Effetto su Saldo: `copie_da_consegnare`/`importo_da_consegnare` diventano
residui reali per riga (valorizzati al prezzo scontato), non più binari.

Backfill: ogni Consegna esistente riceve `consegna_righe` a quantità piena.

## 4. Acconti e tipo di pagamento atteso

```ruby
# pagamenti: cade l'indice unique su pagabile → has_many
add_column :pagamenti, :importo_cents, :bigint, null: false, default: 0
add_column :documenti, :tipo_pagamento_previsto, :string
```

`Pagabile` rivisto:

- `mark_pagato` (fast path) → Pagamento con `importo_cents` = residuo,
  tipo default = `tipo_pagamento_previsto`
- `registra_acconto!(importo:, tipo_pagamento: nil, pagato_il: nil)` →
  acconto libero; valida `importo ≤ residuo`
- `pagato?` = `pagamenti.any?` **e** residuo ≤ 0 (il check `any?` evita che
  documenti a totale zero — saggi — risultino "pagati" da soli)
- `parzialmente_pagato?` = acconti presenti ma residuo > 0
- `residuo_da_pagare_cents` = `totale_cents` − Σ acconti
- `tipo_pagamento` (lettura) = tipo dell'ultimo pagamento
- `unmark_pagato` → distrugge un acconto specifico

Form documento: `tipo_pagamento_previsto` nello step `tipo_documento`
(select con `Pagamento::TIPI_PAGAMENTO`), opzionale. Abilita liste come
"cedole da incassare" (`where(tipo_pagamento_previsto: "cedole")` + residuo > 0).

Propagazione ai figli: quando il padre risulta *interamente* pagato, i figli
vengono saldati col tipo dell'ultimo acconto (scatta sulla saturazione, non sul
primo pagamento). `auto_close_se_completo` scatta quando `pagato? && consegnato?`
diventano veri.

Effetto su Saldo: `importo_da_pagare` = Σ residui reali (con segno causale).

Backfill: pagamenti esistenti ricevono `importo_cents = documento.totale_cents`.

## 5. Reader: UI, Movimenti, export

- `libri#show`/`edit` leggono `@libro.giacenza` dalla tabella. Badge helper:
  da `giacenza&.ordini` a `giacenza&.impegnato`. Liste: `includes(:giacenza)`.
- `Libro::Movimenti` resta il reader di dettaglio (liste righe + riepilogo per
  anno), allineato: scoping account in `righe_base`, `causale.segno` al posto
  di `segno_per`, `da_consegnare` = complemento esatto di `impegnato`,
  nomenclatura identica alla tabella.
- Export xlsx: `Libro.crosstab` e `LibroSituazio` sostituiti da query object
  `Libro::Situazione` (in `app/models/libro/`): query FILTER per causale,
  bind params, solo documenti padre-nil, scoping account. Pivot in Ruby,
  niente estensione `crosstab()`. Route e azione rinominate
  `crosstab` → `situazione`.
- L'estensione Postgres `tablefunc` resta installata: la usano le query Blazer
  generate da `lib/tasks/blazer.rake` (fuori scope).

## 6. Migrazione, cleanup, test

Migrazione (una migration + deploy in un colpo, backfill guardato):

1. `create_table :giacenze`, `create_table :consegna_righe`,
   `add_column` su pagamenti/documenti, drop indici unique su consegne/pagamenti
2. Backfill: consegna_righe a quantità piena, importo_cents = totale,
   `Giacenza.ricalcola_tutte!` per ogni account
3. `drop_view :view_giacenze` (Scenic) + rimozione `db/views/view_giacenze_v01.sql`
4. A fine lavoro: drop colonne legacy `documenti.status`, `consegnato_il`,
   `pagato_il`, `tipo_pagamento` (integer)

File eliminati:

- `app/models/views/giacenza.rb` + vista SQL
- `app/services/libro_info.rb` (mai usato, buggato)
- `app/services/libro_situazio.rb`
- `Libro.crosstab` (metodo raw SQL)
- `Libro::Movimenti#segno_per` (sostituito da `causale.segno`)

Test (Minitest + fixtures):

- `giacenza_test.rb` — il cuore: carico fornitore, vendita non consegnata
  (→ impegnato), consegna parziale (split impegnato/venduto), vendita
  consegnata, TD04 consegnata (rientro), campionario, catena padre/figlio
  (il figlio non conta), altro account (escluso)
- `causale_test.rb` — `segno`, predicati `magazzino_*`
- Consegnabile: consegna totale/parziale, residui, consegnato?, unmark
- Pagabile: acconti, saturazione, residuo, tipo previsto come default,
  totale zero, propagazione ai figli alla saturazione
- Trigger: consegna/documento_riga/riga → ricalcolo giacenza
- `libro/situazione_test.rb` — export: colonne per causale, esclusione figli,
  scoping account

Ordine di lavoro (ogni step lascia l'app funzionante):

1. Causale (segno + enum magazzino)
2. Tabella + modello Giacenza + ricalcolo
3. Consegne parziali (schema + Consegnabile)
4. Acconti + tipo previsto (schema + Pagabile)
5. Trigger nei concern + Saldo sui residui
6. Switch UI/badge + Movimenti refactor
7. `Libro::Situazione` + rename route
8. Cleanup finale (file morti, colonne legacy)
