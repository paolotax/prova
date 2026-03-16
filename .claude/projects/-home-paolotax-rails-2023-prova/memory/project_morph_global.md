---
name: morph_global_blocked
description: Morph globale nel layout causa sfarfallio show e refresh continuo kanban dopo drop
type: project
---

Tentativo di morph globale (come Fizzy) fallito il 2026-03-16.

**Problemi riscontrati:**
1. Sfarfallio sulle show page quando si naviga avanti/indietro (preview cache di Turbo)
2. Kanban fa refresh continuo ad ogni drop (problema già corretto in passato, riappare con morph globale)

**Stato attuale:**
- Morph è **per-page** (solo sulle pagine che ne hanno bisogno)
- Le show page hanno `no-cache` (`turbo-cache-control`) per evitare sfarfallio da preview cache
- Pagine con morph: appunti/index, appunti/show, documenti/index, documenti/show, dashboard/index, scuole/index, scuole/show, tappe/show, accounts/aree/show

**Why:** Il morph globale non funziona in Prova a causa del kanban drag & drop (Sortable crea cloni DOM che il morph preserva/duplica) e della preview cache che causa sfarfallio.

**How to apply:** Non spostare morph nel layout. Se si vuole riprovare, bisogna prima risolvere il problema kanban (probabilmente con `data-turbo-temporary` sugli elementi drag) e il caching delle show.
