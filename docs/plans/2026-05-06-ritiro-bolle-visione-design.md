# Ritiro Bolle Visione — Design

**Data:** 2026-05-06
**Branch:** `feature/ritiro-bolle-visione`

## Contesto

A fine anno scolastico l'utente (rappresentante) deve **ritirare i libri** che ha lasciato in visione nelle scuole tramite `BollaVisione`. Per ogni libro/riga della bolla deve decidere:

- libri **adottati** → restano in saggio nella scuola (Scarico Saggi)
- libri **venduti** → emette fattura (TD01) o registra come corrispettivo (Ordine Scuola)
- libri **mancanti/persi** → segnala alla scuola/referente con un documento dedicato (con prezzi pieni)
- libri **rientrati** in campionario → spunta semplice, nessun documento
- caso parziale: di una **confezione** possono mancare solo alcuni fascicoli

Inoltre alcuni utenti potrebbero non aver compilato bolle visione; in quel caso si lavora **a partire dalla collana** (bolla retroattiva).

## Modello dati

### Modifiche a `BollaVisioneRiga`

```ruby
add_column :bolla_visione_righe, :esito, :integer
add_column :bolla_visione_righe, :processato_at, :datetime
add_reference :bolla_visione_righe, :documento_riga, foreign_key: true
add_index :bolla_visione_righe, [:bolla_visione_id, :esito]
```

```ruby
class BollaVisioneRiga < ApplicationRecord
  enum :esito, {
    in_saggio: 0,             # Scarico Saggi
    venduto_fattura: 1,       # TD01
    venduto_corrispettivi: 2, # Ordine Scuola
    mancante: 3,              # nuova causale "Mancante"
    rientrato: 4              # nessun documento
  }

  belongs_to :documento_riga, optional: true

  scope :aperte, -> { where(processato_at: nil) }
  scope :chiuse, -> { where.not(processato_at: nil) }
end
```

`processato_at` è la singola fonte di verità "riga chiusa". Una riga `rientrato` ha `processato_at` ma `documento_riga_id = nil`; le altre hanno entrambi.

**No `fascicoli_mancanti jsonb`**: i fascicoli mancanti vengono modellati come righe distinte (vedi sezione fascicoli).

### Nuova causale "Mancante"

```ruby
Causale.find_or_create_by!(causale: "Mancante") do |c|
  c.tipo_movimento = :carico
  c.movimento = :uscita
  c.magazzino = "campionario"
  c.clientable_type = "Scuola"
end
```

### Bolla aperta/chiusa

Una `BollaVisione` è "aperta" quando `bolla_visione_righe.aperte.exists?`. Niente colonna stato esplicita: la condizione è derivata.

## UX

### Entry points

- **Scuola show**: tab/sezione "Ritiro" visibile solo se `scuola.bolle_visione.joins(:bolla_visione_righe).where(bolla_visione_righe: { processato_at: nil }).exists?`
- **Tappa show**: card "Bolle aperte da ritirare" che linka a `scuole/:id/ritiro` se `tappa.tappable` è `Scuola`

### Pagina `scuole/:id/ritiro`

Lista raggruppata per **bolla → gruppo (CollanaLibro.gruppo)**, righe `aperte` ordinate. Ogni riga: checkbox + libro + prezzo + bottone `↩ rientro`. Footer sticky con counter selezione + dropdown azioni (Scarico Saggi / TD01 / Ordine Scuola / Mancante).

```
┌─ Bolla BV-12 (Collana A) ───────────────────────────┐
│ ━ Italiano ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│   ☐ Grammatica         €15,00       [↩]            │
│   ☐ Antologia          €18,00       [↩]            │
│ ━ Storia ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│   ☐ Atlante 1+2+3      €22,00       [↩]            │
│ ━ Altro ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│   ☐ ...                                             │
├─ Bolla BV-15 (Collana B) ───────────────────────────┤
│ ...                                                  │
└──────────────────────────────────────────────────────┘
☐ Selezionate: 0   [Genera documento ▼]
```

Le righe **chiuse** non appaiono qui — vivono nello show della BollaVisione (con badge esito + link al documento generato).

### Azioni

- **Rientro one-click** (`PATCH /bolla_visione_righe/:id/rientro`): setta `esito: :rientrato`, `processato_at: now`. Turbo Stream rimuove la riga dalla lista.
- **Genera documento** (`POST /bolle_visione/ritiri`): apre dialog di conferma con clientable (default `Scuola`, modificabile in `Persona` o altro), data, riepilogo righe, eventuali campi specifici della causale.
- **Riapri riga** (sullo show bolla): cancella `DocumentoRiga`, cancella `Documento` se vuoto, resetta `esito`/`processato_at`/`documento_riga_id`.
- **Splitta riga** (caso `quantita > 1` con esiti misti): genera N righe `quantita: 1` dalla originale.

## Generazione documenti

`RitiriController#create` (transazione):

```ruby
documento = scuola.documenti.create!(
  causale: causale,
  clientable: chosen_clientable,
  data: params[:data],
  user: Current.user
)

righe.each do |bv_riga|
  doc_riga = documento.documento_righe.create!(
    libro: bv_riga.libro,
    quantita: bv_riga.quantita,
    prezzo_cents: bv_riga.libro.prezzo_cents
  )
  bv_riga.update!(
    esito: causale_to_esito(causale),
    documento_riga: doc_riga,
    processato_at: Time.current
  )
end
```

- **1 documento per submission** (raccoglie tutte le righe selezionate)
- **L'utente ripete il flusso** per le altre causali / clientable
- **Mancante**: prezzi pieni dal libro, così la scuola vede il valore di quanto manca

### Mancante su confezione (split fascicoli)

Se nella selezione c'è una riga-confezione (`libro.fascicoli.any?`) e l'azione è "Mancante":

1. **Dialog intermedio** "Quali fascicoli mancano?" con checkbox dei `libro.fascicoli`
2. L'utente seleziona i fascicoli mancanti + sceglie l'esito da applicare alla riga-confezione originale (rientrato / in_saggio / venduto)
3. Sistema:
   - crea N nuove `BollaVisioneRiga` (una per fascicolo selezionato) con `libro_id = fascicolo.id`, `quantita: 1`, esito `:mancante`
   - chiude la riga-confezione originale con l'esito scelto
4. Procede alla creazione del documento Mancante con le N righe-fascicolo + altre righe Mancante selezionate

Risultato: il documento Mancante elenca **fascicoli singoli** con prezzi pieni — la scuola sa esattamente cosa serve.

## Casi edge

### Scuola senza bolle (o aggiunta collane)

Pulsante **"Crea bolle da collane"** con multi-select collane:

```
[ ] Collana A
[ ] Collana B
[ ] Collana C
       [ Crea bolle ]
```

Per ogni collana selezionata crea **una `BollaVisione`** (`belongs_to :collana` singola) con `data_bolla = Date.current`, popolata da `crea_righe_da_collana!` (senza filtro target). N collane = N bolle. Disponibile anche se la scuola ha già qualche bolla.

### Quantità > 1 con esiti misti

Eccezione rara. Pulsante **"Splitta riga"** sulla riga aperta → input "in quante parti?" → genera N righe con `quantita: 1` (cancella o riduce l'originale). Poi processa ogni riga separatamente.

### Annullamento esito

Bottone **"Riapri"** sullo show della BollaVisione (non nella pagina ritiro):
- riga con `documento_riga_id`: cancella `DocumentoRiga`; se il `Documento` resta vuoto lo cancella; resetta riga
- riga `rientrato`: resetta solo i campi

### Bolle con esiti misti

Lo show della bolla mostra righe aperte e chiuse insieme (chiuse con badge esito + link al documento generato). La pagina ritiro mostra solo le aperte.

## Test

**Modelli (Minitest, fixtures):**
- `bolla_visione_riga_test.rb`: scope `aperte`/`chiuse`, enum `esito`, fixtures per ogni stato
- `bolla_visione_test.rb`: derivazione "aperta/chiusa" via righe

**Controller integration:**
- `ritiri_controller_test.rb`:
  - genera Scarico Saggi da N righe → 1 Documento, N DocumentoRiga, righe chiuse con `documento_riga_id`
  - genera TD01 con clientable=Persona
  - genera Mancante: confezione → split fascicoli → DocumentoRiga = fascicoli singoli, riga confezione chiusa con esito scelto
  - rientro: `processato_at` settato, `documento_riga_id` nil
  - riapri riga: cancella DocumentoRiga, cancella Documento se vuoto
  - split riga `quantita > 1`
  - crea bolle retro da collane multiple (transazione, N bolle)

**System (Capybara):**
- end-to-end: scuola → tab ritiro → spunta righe → genera TD01 → torna alla pagina con righe rimanenti

## Ordine implementazione

1. Migrazione + modello (`esito`, `processato_at`, `documento_riga_id`, scope, enum). Test modello
2. Causale "Mancante" seed + verifica stampa PDF (riusa stampa Documento esistente)
3. `RitiriController` + viste: pagina `scuole/:id/ritiro` con lista raggruppata per bolla/gruppo
4. Generazione documenti (4 esiti standard) con dialog conferma + clientable. Turbo Stream
5. Azione "rientro" one-click + bottone "Riapri" sullo show bolla
6. Caso Mancante su confezione: dialog selezione fascicoli + split
7. Split quantità > 1 (può venire dopo, è eccezione)
8. Crea bolle retro da collane multiple: form multi-collana
9. Tab Ritiro su Tappa show
10. System test end-to-end

## File toccati

- `db/migrate/AAAA_add_ritiro_to_bolla_visione_righe.rb`
- `db/seeds.rb` (causale Mancante)
- `app/models/bolla_visione_riga.rb`, `bolla_visione.rb`
- `app/controllers/ritiri_controller.rb` (nuovo)
- `app/controllers/bolla_visione_righe_controller.rb` (rientro, riapri, split)
- `app/views/ritiri/` (nuovo)
- `app/views/scuole/_ritiro_tab.html.erb`, `tappe/_bolle_aperte.html.erb`
- `app/views/bolla_visione_righe/_bolla_visione_riga.html.erb` (badge esito + Riapri)
- `test/models/bolla_visione_riga_test.rb`, `test/controllers/ritiri_controller_test.rb`, system test

## Decisioni di design

- **Una sola BollaVisioneRiga = un solo esito**: niente jsonb di stato, fascicoli mancanti come righe distinte (split). Modello pulito, query semplici, audit naturale.
- **`processato_at` come fonte di verità**: derivare "aperta/chiusa" da nulità del timestamp evita una colonna `stato` ridondante.
- **Bolla retro come BollaVisione vera**: niente modello separato per "ritiro libero". Tutto il flusso lavora sempre su `BollaVisione`.
- **Documenti aggregati per submission**: 1 documento per click → l'utente è libero di ripetere il flusso più volte con clientable diversi (caso per caso come richiesto).
- **Causale "Mancante" come carico/uscita/campionario**: coerente con "Scarico saggi"; la sua peculiarità è il PDF dedicato, non il movimento di magazzino.
