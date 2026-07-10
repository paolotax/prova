# Causali senza pagamento + distinzione clienti/fornitori

Data: 2026-07-10 — Stato: design validato, implementazione non iniziata

## Problema

1. Il pagamento oggi compare su **tutti** i documenti (card, tabella, dialog Gestione,
   bulk, saldo), anche dove non ha senso: campionario, saggi, conto visione, carichi
   fornitore. Un Conto visione non pagato gonfia il "da pagare" del cliente e uno
   Scarico saggi consegnato non si auto-chiude mai (aspetta un pagamento che non arriverà).
2. Non esiste una distinzione clienti/fornitori: i fornitori (GIUNTI, GAIA, TREDIECI,
   MONDADORI...) sono normali record `Cliente`, distinguibili solo dalle causali usate.
   `Views::Fornitore` (Scenic, deprecata) regge ancora `FornitoriController`.
   Alcuni soggetti sono sia clienti che fornitori: il ruolo non è esclusivo.

## Contesto dominio (dal confronto con Paolo)

- Due giacenze: **vendita** e **campionario** (già modellate in `Giacenza`).
- Ciclo campionario: Campionario (carico da editore) → Scarico saggi (consegna fisica
  agli insegnanti, dal 2026) / Conto visione (scuole) → **saggi** (sconto 100) e
  **saggi 50** (sconto 50): scarichi *figurativi* verso l'editore, quantità calcolate
  sulle adozioni dell'anno (`CampionarioController#genera_saggi*`), per la dichiarazione
  di giacenza di fine anno. Le differenze si pagano al 20% o 45% con fattura (TD24).
- Il file del portale Giunti fa testo come inventario campionario di riferimento.
- TD04 e Resa Cliente scalano dal fatturato → pagamento (rimborso) tracciato.
- TD24 = fattura di acquisto: pagamento tracciato per sapere cosa è stato pagato.

## Decisioni

### 1. `causali.gestione_pagamento` (boolean, default true, not null)

- **true**: Ordine Cliente, Documento di trasporto, Ordine Scuola, TD01, TD04,
  Resa Cliente, TD24
- **false**: DDT Fornitore, Carico Fornitore, Resa a Fornitore, Campionario,
  Campionario Resa, saggi, saggi 50, Controllo Giacenza, Conto visione, Scarico saggi
- Checkbox nel form causali, colonna nella lista causali.
- `Documento#pagamento_applicabile?` delega a `causale.gestione_pagamento?`;
  documento senza causale (bozza) → true.

### 2. `clienti.fornitore` (boolean, default false, not null)

- Ruolo additivo, non esclusivo: un fornitore resta selezionabile come cliente.
- Backfill: true per i clienti con almeno un documento di contesto Fornitori/Campionario.
- Checkbox nel form cliente, scope `Cliente.fornitori`.
- Il contesto causale (Vendite/Fornitori/Campionario) resta derivato da
  `tipo_movimento` + `magazzino` come oggi: nessuna colonna contesto.

## Comportamento con `gestione_pagamento = false`

UI — il blocco pagamento sparisce:
- `documenti/display/preview/_meta`, `display/perma/_meta`, `display/perma/_tags`:
  niente cash / "DA PAGARE" / tipo pagamento
- `documenti/table/_row`: colonna pagamento e valori mobile → "—"
- `documenti/container/_gestione_dialog_content`: sezione Pagamento non renderizzata
- `documenti/bulk_gestione/_pagamento`: salta i non pagabili; sezione assente se
  la selezione è tutta non pagabile
- `documenti/container/_content`: campo "Pagamento previsto" nascosto via Stimulus
  quando la causale non gestisce il pagamento (pattern `causale-clientable`)

Logica:
- `Pagabile#registra_acconto!`: guardia che rifiuta pagamenti su non pagabili
  (protegge anche MCP/API)
- `Documento#auto_close_se_completo`: `consegnato? && (pagato? || !pagamento_applicabile?)`
- `Saldo#residui_pagamenti`: `AND causali.gestione_pagamento` nel WHERE
  (il da_consegnare resta invariato); ricalcolo saldi di tutti dopo la migrazione
- Tab `da_pagare` in `VenditeController` e filtro `pagati` in `DocumentoFilter`:
  escludono i non pagabili
- Pagamenti già registrati su documenti non pagabili: restano visibili per ora,
  non se ne aggiungono di nuovi (pulizia in coda, vedi sotto)

## Fornitori nella UI

- Combobox destinatari filtrata per contesto: causale con contesto Fornitori/Campionario
  e `Cliente` tra i `clientable_types` → endpoint `destinatari_index_path` chiamato con
  `fornitori=1` → solo `Cliente.fornitori`. Causali Vendite → come oggi.
  Conto visione / Scarico saggi (verso scuole/classi/persone) non sono toccate:
  il filtro fornitori vale solo per il tipo Cliente.
  Meccanica: `data-contesto` sul select causale, letto dal controller Stimulus.
- `FornitoriController`: da `Views::Fornitore` a `Cliente.fornitori`
  (rimozione debito tecnico).
- `ClienteFilter`: opzione "solo fornitori".

## Estensione (decisa 2026-07-10, dopo l'implementazione del pagamento): consegna e importo

### `causali.gestione_consegna` (boolean, default true, not null)

- **true**: tutte le Vendite (Ordine Cliente, Documento di trasporto, Ordine Scuola,
  TD01, TD04, Resa Cliente) + **Scarico saggi** (la consegna fisica agli insegnanti
  è il suo scopo) + **Conto visione** (merce portata fisicamente a scuola)
- **false**: DDT Fornitore, Carico Fornitore, TD24, Resa a Fornitore, Campionario,
  Campionario Resa, saggi, saggi 50, Controllo Giacenza
- `Documento#consegna_applicabile?` speculare a `pagamento_applicabile?`
  (bozza senza causale → true)
- Nota verificata: la Giacenza NON è toccata — il gating sulle consegne vale solo
  per `tipo_movimento = vendita`; carichi e campionario contano la quantità piena.

Comportamento speculare al pagamento:
- UI: card preview/perma, tabella (colonna consegna → "—"), dialog Gestione
  (sezione Consegna non renderizzata), bulk consegne (salta i non applicabili)
- `Consegnabile`: guardia su mark_consegnato/registrazione consegna
- `Saldo#residui_consegne`: `AND causali.gestione_consegna` nel WHERE
  (+ ricalcolo saldi dopo la migrazione)
- `auto_close_se_completo`: `(consegnato? || !consegna_applicabile?) &&
  (pagato? || !pagamento_applicabile?)`. Documenti con entrambe le gestioni
  spente: nessuna auto-chiusura, si chiudono manualmente (triage) — com'è oggi.
- Tab/filtro `da_consegnare` (VenditeController + DocumentoFilter): escludono
  i non applicabili (stesso pattern subquery su causale_id)
- Checkbox nel form causali + colonna nella lista

### `causali.mostra_importo` (boolean, default true, not null)

- **false** solo per **Scarico saggi**: righe a sconto 100, l'importo è sempre
  €0,00 → rumore. Card e tabella nascondono il campo IMPORTO
  (copie restano visibili). Saggi/saggi 50 mantengono l'importo
  (per saggi 50 è il valore pagato all'editore).

## Fuori scope / passi successivi

1. **Pulizia pagamenti** registrati per errore su documenti non pagabili (deciso: si fa, dopo).
2. **Reintestazione dei 9 TD24** intestati a "TASSINARI PAOLO" → editore emittente,
   da fare insieme documento per documento a fine implementazione.
3. Flusso riconciliazione file portale Giunti → conteggi saggi → comunicazione giacenza:
   resta manuale, nessuna modifica.
4. Eventuale migrazione dello storico ambiguo: "saggi" usata pre-2026 anche per le
   consegne fisiche alle scuole (~68 doc) e "Campionario" intestata a scuole (16 doc).
   Non urgente, tenerne conto nelle query per editore.
