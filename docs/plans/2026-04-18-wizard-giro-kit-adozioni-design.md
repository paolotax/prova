# Wizard Giro — opzione kit_adozioni con selezione libri

Data: 2026-04-18

## Obiettivo

Il wizard di creazione di un Giro, quando il tipo è `kit_adozioni`, deve permettere all'utente di selezionare uno o più libri dalle proprie adozioni attive (`mia: true, disdetta: false`), e usarli per filtrare la lista scuole mostrata nello step successivo. Le tappe generate dal giro memorizzano nelle `note` l'elenco dei libri selezionati presenti in adozione nella scuola di destinazione, con le classi.

## Flusso

Per `kit_adozioni` il wizard passa da 4 a 5 step:

1. Tipo giro
2. Dettagli giro
3. **Libri** *(nuovo)*
4. Scuole (filtrate OR sui libri scelti: almeno uno in adozione)
5. Riepilogo

Per gli altri tipi di giro il flusso resta identico al comportamento attuale.

Regole:
- Lista libri raggruppata per `classe → disciplina → titolo` (gerarchia a tre livelli come scuole).
- Bottone "Avanti" disabilitato finché `libro_ids.size == 0`.
- Step scuole default `match_mode=or`; l'utente può passare a `and` con un toggle che ricarica il frame.
- Se l'utente torna allo step libri dopo aver già scelto scuole, appare un `turbo-confirm` "Cambiare i libri azzererà la selezione scuole. Continuare?".

## Persistenza

**Nessun nuovo modello, nessuna nuova colonna.** I libri selezionati vivono solo come param del wizard. Al `create`, per ogni tappa generata scriviamo sui campi esistenti di `Tappa`:

- `titolo` — riassunto breve, es. `"Kit adozioni: 3 libri"`
- `descrizione` — elenco piatto separato da ` · `, es. `"Titolo A (1A, 2B) · Titolo B (3C)"`

I campi vengono sovrascritti (le tappe create dal wizard nascono con titolo/descrizione nulli).

## Controller

`Giri::WizardController`:

- nuova action `libri` (GET), popola `@libri_gerarchia` e `@conteggio`.
- `scuole` accetta `libro_ids[]` e `match_mode` (`or`|`and`, default `or`); filtra scuole in `kit_adozioni` sui libri scelti.
- `scuole_per_tipo` impara il filtro libri: OR via `where(libro_id: ids)`, AND via `GROUP BY + HAVING count distinct = ids.size`.
- `create` passthrough di `libro_ids`; dopo `genera_tappe_per`, itera `giro.tappe` e valorizza `note` con il blocco "Kit adozioni".
- helper `libri_mie_attive_gerarchia`: hash ordinato `{classe => {disciplina => [libri]}}` da `Libro` joinati a `Adozione.mie_attive` dell'account corrente, distinct.

## Views

- `app/views/giri/wizard/libri.html.erb` — header con conteggio + Turbo Frame `wizard_libri` con `_libri_tree`.
- `app/views/giri/_libri_tree.html.erb` — gerarchia classe/disciplina/titolo a tre `<details>` annidati, toggle di gruppo via `libri-tree#toggleGroup`.
- `app/views/giri/_libro_row.html.erb` — singolo checkbox `libro_ids[]`.
- `app/views/giri/wizard/scuole.html.erb` — aggiunta fieldset radio OR/AND in cima, con submit automatico al change.

## Stimulus

- `app/javascript/controllers/libri_tree_controller.js` — clone di `scuole_tree_controller.js` con input `libro_ids[]`.
- `app/javascript/controllers/wizard_controller.js`:
  - aggiunta step `libri` (solo per `kit_adozioni`) con `loadLibri()`; la sequenza `steps` viene scelta in `connect()` sulla base del tipo selezionato.
  - `loadScuole()` include `libro_ids` e `match_mode` nella query.
  - `loadRiepilogo()` include `libri_count`.

## Rotte

Aggiungo in `config/routes.rb` sotto `resources :giri`:

```ruby
get 'wizard/libri', to: 'giri/wizard#libri', as: 'wizard_libri'
```

## Test

`test/controllers/giri/wizard_controller_test.rb`:

1. `GET libri` con `tipo_giro=kit_adozioni` → 200 + `@libri_gerarchia` raggruppato.
2. `GET scuole` con `libro_ids=[a,b]` `match_mode=or` → scuole con almeno un libro.
3. `GET scuole` con `libro_ids=[a,b]` `match_mode=and` → solo scuole con tutti.
4. `POST create` per `kit_adozioni` con `libro_ids` → giro + tappe + blocco "Kit adozioni:" nelle note.
5. `POST create` non scrive nulla se la scuola non ha libri in comune.

## Fuori scopo

- Nessun inventario kit, nessun movimento magazzino, nessuna bolla.
- Nessun modello/relazione `TappaLibro`.
- Nessun ordinamento custom delle classi (uso ordine naturale `classe` integer su Libro).
