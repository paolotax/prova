# Giacenze → Conteggi per anno — Design

Data: 2026-07-21

## Problema

La pagina giacenze attuale (fabbisogno, disponibilità libera, campionario a saldo)
non è utilizzabile: i dati sono incompleti perché mancano le chiusure anno per anno.
Servono invece conteggi di riferimento per libro, filtrabili per anno.

## Contesto di dominio

Due mondi distinti:

1. **Magazzino vendita** (proprio, contabile): carichi da fatture acquisto,
   scarichi da vendite/corrispettivi. La logica attuale disponibile/impegnato/venduto
   resta valida come base, ma non è l'oggetto di questa pagina.
2. **Campionario** (dell'editore, ciclo annuale):
   - apertura anno: Excel dal portale editore, importato con causale "Campionario"
     tramite gli import esistenti — fa fede lui;
   - durante l'anno: scarichi saggi effettivi (causale "Scarico saggi", solo
     riferimento) e a volte copie di campionario dentro vendite/corrispettivi;
   - chiusura: si comunica all'editore la giacenza reale contata; l'editore emette
     fatture a sconti concordati ("saggi 100", "saggi 50") e aggiorna il file, che
     diventa l'apertura dell'anno dopo.

I conteggi NON si sommano tra loro: sono letture parallele dello stesso anno.

Decisioni prese:
- Niente campo `magazzino` sulla riga: tutto si legge dalle causali, come oggi.
- Il modello `Saggio` è di fatto inutilizzato (lo scarico avviene via causale
  "Scarico saggi"); l'eventuale rimozione è fuori scope.
- La causale "saggi" va rinominata "saggi 100" (data-fix contestuale alla feature).

## Colonne della tabella (per libro, filtrate per anno)

| Colonna | Fonte |
|---|---|
| Adottati | `libri.adozioni_count` (come oggi, indipendente dall'anno) |
| Campionario | `SUM(righe.quantita)` dei documenti con causale "Campionario" |
| Saggi 100 | idem, causale "saggi 100" |
| Saggi 50 | idem, causale "saggi 50" |
| Scarico saggi | idem, causale "Scarico saggi" — solo riferimento |
| Venduti | copie consegnate dei documenti vendita (logica `venduto_copie` attuale) |
| Da consegnare | residuo `quantita - consegnate` sui documenti vendita (logica `impegnato`) |

Quantità piene, senza segni: sono conteggi di riferimento, non saldi.

## Query

PORO `Giacenza::Conteggi`: GROUP BY `righe.libro_id` con `FILTER` per colonna,
sul modello di `Giacenza::AGGREGATI_SQL`/`FONTE_SQL`:

- colonne per causale: `SUM(righe.quantita) FILTER (WHERE causali.causale = '...')`
- `venduti` / `da_consegnare`: stesse LATERAL su `consegna_righe` di oggi
- sempre: `documenti.account_id = :account_id`, `documento_padre_id IS NULL`,
  `EXTRACT(YEAR FROM data_documento) = :anno`

Calcolo **live in query**, niente denormalizzazione: la tabella `giacenze` non ha
la dimensione anno e la pagina smette di leggerla (tabella e modello restano in
piedi per gli altri consumer, per ora).

Mapping causali esplicito nel PORO (le causali non hanno codice stabile):

```ruby
CAUSALI = {
  campionario:   "Campionario",
  saggi_100:     "saggi 100",
  saggi_50:      "saggi 50",
  scarico_saggi: "Scarico saggi"
}
```

## Controller

`GiacenzeController#index` resta:
- una query per i totali di testata (stessa query senza GROUP BY per libro);
- per le righe: hash `libro_id => conteggi` caricata a parte (o LEFT JOIN LATERAL);
- `Giacenza::Columns` aggiornato alle nuove colonne, ordinabili come oggi;
- filtro anno via `GiacenzaFilter`, default anno corrente.

## Filtri (`Filters::GiacenzaFilter`)

Il nome interno `stato` resta (meno churn); cambiano le opzioni:

```ruby
STATI = {
  "adottati"    => "Adottati",
  "impegnati"   => "Da consegnare",
  "campionario" => "In campionario",
  "venduti"     => "Venduti"
}
```

- Rimossi `fabbisogno` e `sotto_scorta` (e `LIBERO_SQL`).
- `campionario`/`venduti`/`impegnati`: `EXISTS` sulla stessa fonte dei conteggi,
  rispettando l'anno selezionato — filtro e colonne dicono la stessa cosa.
- Nuovo campo `anno` (store_accessor, validato, default anno corrente), select nel
  pannello filtri come in `DocumentoFilter`, voce nel summary ("anno 2026").

## Testata (analytics-summary)

Card: **Adottati · Campionario · Scarico saggi · Venduti · Da consegnare** più la
card venduto in € (già calcolata, utile). Saggi 100/50 solo come colonne tabella.
Rimosse le card fabbisogno/disponibile e la frase esplicativa sul fabbisogno.

## Test

- Test del PORO `Giacenza::Conteggi`: fixture con documenti di causali diverse su
  due anni; verifica rispetto di anno e causale, esclusione dei documenti figli,
  venduti = solo copie consegnate.
- Aggiornamento `test/controllers/giacenze_controller_test.rb` (nuove opzioni
  stato, campo anno, testata).

## Fuori scope

- Rimozione modello `Saggio` / tabella `saggi` (decisione rimandata).
- Chiusura/riapertura campionario assistita (riconciliazione con l'Excel editore).
- Rimozione tabella `giacenze` e dei suoi ricalcoli.

---

# Fase 2 — Card-filtro e layout uniforme (giacenze + documenti)

Decisioni (2026-07-21, seconda iterazione con Paolo):

## Pattern condiviso

Partial `shared/_analytics_filter_cards.html.erb`: riceve `cards:` (lista di
`{key:, value:, label:, value_class:}` — `key: nil` = KPI non cliccabile),
`current:`, `url:`, `param:`. Ogni card con key è un `link_to` full-page
(`data: { turbo_action: "advance" }`, NESSUN turbo_frame): un click aggiorna
righe, card e pannello filtri insieme. Card attiva = `--active`; il suo link
rimuove il param (toggle off). I link preservano gli altri parametri
(`request.query_parameters.except("page")`).

CSS: variante `.analytics-summary__card--link` in `analytics.css`
(generalizza hover/active oggi scopati su `.ca-page`; controllo adozioni
NON si tocca — resta client-side).

Numeri card: scope filtrato da tutto TRANNE lo stato (pattern `stato_counts`
di `DocumentoFilter`).

Layout uniforme: header → card analytics → filters/settings → frame
`search_results`.

## Giacenze

- STATI completo (una voce per colonna): adottati, campionario, saggi_100,
  saggi_50, scarico_saggi, venduti, impegnati ("Da consegnare").
- `GiacenzaFilter#libri(ignora_stato: false)`: stessa query, salta il case
  stato; il controller la usa per `@totali`.
- Card: le 6 attuali — adottati/campionario/scarico saggi/vendute/da
  consegnare cliccabili (stati adottati/campionario/scarico_saggi/venduti/
  impegnati), venduto € non cliccabile. Saggi 100/50 solo nel picker stato.

## Documenti

- `documenti/_stato_tabs.html.erb` eliminato, sostituito dal partial
  condiviso FUORI dal frame, sopra filters/settings.
- Card: Tutti, Attivi, Da consegnare, Da pagare, Completati con
  `@stato_counts` esistenti; `current` = stato_documento o "attivi";
  toggle → rimuove il param (default attivi).
- Nessun cambio a `DocumentoFilter`.

## Fuori scope fase 2

- Propaganda: usa ancora `doc-stato-tabs` (suo `_stato_tabs`), quindi il CSS
  `doc-stato-tab*` RESTA; migrazione alle card in un eventuale follow-up.
