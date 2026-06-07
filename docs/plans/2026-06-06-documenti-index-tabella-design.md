# Documenti index — da card a tabella

**Data:** 2026-06-06
**Stato:** Design validato, pronto per implementazione

## Problema

La index dei documenti usa una vista a card copiata da Fizzy (`cards--grid`),
percepita come confusa. Obiettivi del redesign:

1. **Densità / scansione veloce** — vedere più documenti insieme
2. **Confronto in colonne** — dati allineati (data, importo, copie, stato)
3. **Stato a colpo d'occhio** — capire consegna/pagamento senza aprire il documento
4. **Filtri e ricerca più efficaci** — trovare un documento in pochi secondi

## Decisioni

- **Tabella piatta** — niente raggruppamento per mese/anno; colonna Data ordinabile
- **Referente e righe libri** restano solo nel dettaglio, non diventano colonne
- **Si tiene**: selezione multipla + bulk bar, stati golden/triage, paginazione
  infinita, export xlsx, ricerca native app
- **Cade**: drag&drop (affordance da kanban) e raggruppamento per mese
- **Niente filtro periodo da/a** per ora — resta solo il filtro anno esistente

## 1. Layout tabella e colonne

Si estende il componente nativo già esistente `documento-table.css` (oggi usato
per le righe dentro il dettaglio documento), che fornisce già: header (nascosto
su mobile), righe con hover / selezione tastiera (`aria-selected`,
focus-visible), celle `--title` (ellissi) / `--right` (tabular-nums) / nascoste
su mobile, riga valori per mobile, stato vuoto.

Tabella piatta, una riga per documento, header sticky, riga cliccabile → dettaglio.

| # | Colonna | Contenuto | Allineam. | Mobile |
|---|---|---|---|---|
| 1 | ☐ | checkbox selezione | center | sì |
| 2 | **Stato** | pallini consegna+pagamento + 🪙 golden | center | sì |
| 3 | **Documento** | `FATTURA #123` con colore causale; sotto, piccolo, colonna kanban se triaged | start | sì |
| 4 | **Collegati** | chip dei derivati `causale + numero` (es. `→ DDT 45` · `→ FT 12`), link al figlio; "—" se nessuno; `+N` oltre 2 | start | nascosta |
| 5 | **Cliente / Scuola** | denominazione (grassetto) + comune/classe sotto, ellissi — colonna elastica | start | sì (titolo) |
| 6 | **Data** | `06/06/2026` | start | riga valori |
| 7 | **Copie** | totale copie | right | riga valori |
| 8 | **Importo** | totale € | right | riga valori |
| 9 | **Consegna** | data 🚚 o "—" | right | riga valori (sempre visibile) |
| 10 | **Pagamento** | `💵 data + tipo` (es. `15/06 Bonifico`) o `DA PAGARE` | right | riga valori (sempre visibile) |

**Collegati** = `documenti_derivati` (l'index mostra `solo_padri`; i documenti
collegati sono i figli derivati: ORDINE → DDT → FATTURA). Chip con causale
abbreviata + numero, senza data.

### Mobile

Le colonne Consegna e Pagamento **non si nascondono**: confluiscono nella riga
valori, perché data e tipo pagamento sono informazioni di prima importanza.

```
☐ ●● FATTURA #123        Scuola Manzoni · MILANO
   06/06/2026 · 3 copie · € 145,00
   🚚 12/06   💵 15/06 Bonifico
```

## 2. Indicatore di Stato (colonna 2)

Due pallini affiancati + eventuale icona golden, come riassunto visivo rapido.
Il dato "vero" (date + tipo) si legge nelle colonne dedicate 9-10.

```
●●   consegnato + pagato      (entrambi verdi)
●○   consegnato, da pagare    (verde + grigio)
○○   da consegnare e pagare   (entrambi grigi)
🪙●● golden + completo
```

- Pallino 1 = consegna: verde pieno se `consegna` presente, contorno grigio se no
- Pallino 2 = pagamento: verde pieno se `pagamento` presente, grigio se no
- 🪙 golden: icona prima dei pallini se golden
- Completato (closed): riga leggermente attenuata (opacity) + pallini verdi
- `title`/tooltip su ogni pallino: "Consegnato il 12/06" / "Da pagare"
- Colori: variabili esistenti (`--color-positive`, `--color-ink-muted`); niente
  colori nuovi

## 3. Filtri e ricerca

L'infrastruttura filtri (pannello Fizzy, filtri salvati, `FilterScoped`,
`Filters::DocumentoFilter`) è condivisa con altre risorse → si mantiene e si
estende, non si riscrive.

### 3.1 Ricerca intelligente (modifica al filtro)

Oggi il box `terms` cerca solo `scuole.denominazione`, `clienti.denominazione`,
`documenti.referente`. Si estende lo stesso termine a:

- **numero documento** — se il termine è numerico,
  `OR documenti.numero_documento = :n`
- **titolo libro / ISBN** delle righe — via subquery `EXISTS` su `righe → libri`
  (no righe duplicate):
  ```sql
  OR EXISTS (
    SELECT 1 FROM documento_righe dr
    JOIN righe r ON r.id = dr.riga_id
    JOIN libri l ON l.id = r.libro_id
    WHERE dr.documento_id = documenti.id
      AND (l.titolo ILIKE :term OR l.codice_isbn ILIKE :term)
  )
  ```

### 3.2 Tab di stato sempre visibili (con conteggi)

`stato_documento` (Attivi / Da consegnare / Da pagare / Completati / Tutti) esce
dal pannello a comparsa e diventa una **barra segmentata sopra la tabella**, con
**conteggio per tab** (es. `Da pagare (12)`).

I conteggi si calcolano sullo scope già filtrato dagli *altri* filtri (ricerca,
causale, tipo pagamento, anno…) ma **prima** del filtro di stato, così i numeri
riflettono cosa si vedrebbe cliccando ciascun tab. Poche `count` aggiuntive; se
diventano lente, si rendono opzionali.

### 3.3 Restano nel pannello a comparsa

Causali, tipo pagamento, tipo clientable, ordinamento — come oggi. Anche il
filtro **anno** resta invariato (nessun periodo da/a).

## 4. Note tecniche

- **includes filtro**: aggiungere `documenti_derivati: :causale` agli `includes`
  di `Filters::DocumentoFilter#documenti` (colonna Collegati, evita N+1).
- **Nuovo partial riga-tabella** (es. `documenti/table/_row.html.erb`); in
  `index.html.erb` sostituire `cards--grid` + `_documento` con
  `<table class="documento-table__table">` e `<tbody>`. La card resta disponibile
  per altri contesti (kanban/show): si tocca **solo** la index.
- **CSS**: estendere `documento-table.css` (già caricato) con le classi mancanti
  per la index — header sticky, colonna stato, chip collegati. Nessun file nuovo.
- **Selezione/tastiera**: la checkbox col. 1 alimenta `bulk-actions`; la
  navigazione tastiera usa `navigable-list` (già supportato dal CSS via
  `aria-selected`/focus-visible). Bulk bar (Stampa/Gestione/Stato/Elimina)
  invariata.
- **Paginazione**: mantenere `with_automatic_pagination` dentro il `<tbody>`.
- **Export xlsx + ricerca native app**: pulsanti header e `native_search_filter`
  restano.

## Riepilogo decisioni finali

1. Tabella piatta (no raggruppamento mese), header sticky, riga cliccabile
2. Colonne: ☐ · Stato · Documento · Collegati · Cliente/Scuola · Data · Copie · Importo · Consegna · Pagamento
3. Stato = 2 pallini (consegna/pagamento) + 🪙 golden; date/tipo pagamento sempre visibili
4. Ricerca estesa: denominazione + referente + numero documento + libro/ISBN
5. Tab di stato con conteggi sopra la tabella
6. Anno resta come filtro (niente periodo da/a); causali / tipo pagamento / tipo clientable / ordinamento nel pannello a comparsa
7. Restano: selezione + bulk bar, golden/triage, paginazione infinita, export xlsx, ricerca native. Cade: drag&drop e raggruppamento mese
