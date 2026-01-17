# Prova - Completamento Filter Pattern Documenti

## What This Is

App Rails per gestione adozioni libri scolastici, documenti/fatture, e percorsi di vendita per il settore education italiano. Multi-tenancy URL-based già implementata. Questo milestone completa il Filter Pattern per i Documenti.

## Core Value

I documenti devono essere filtrabili per causale, stato, tipo cliente e anno - con la stessa UX già funzionante per Clienti e Appunti.

## Requirements

### Validated

- ✓ Multi-tenancy con Account/Membership — existing
- ✓ Current.account/user context — existing
- ✓ Filter Pattern base (FilterScoped, Filters::Base) — existing
- ✓ Filters funzionanti per Clienti, Appunti, Libri, Scuole — existing
- ✓ Filters::Documento con causali, statuses, tipi_pagamento, anno — existing
- ✓ Ricerca testo su scuola/cliente/referente — existing

### Active

- [ ] Fix filter_url e filter_type nella view documenti/index
- [ ] Aggiungere filtro clientable_type (Cliente vs ImportScuola)
- [ ] Aggiornare Filtering con clientable_types_disponibili
- [ ] Verificare UI filtri funzionante

### Out of Scope

- Intervallo date (da/a) — anno è sufficiente per ora
- Nuovi filtri oltre clientable_type — scope limitato a completare l'esistente
- Refactoring multi-tenancy — lasciare com'è

## Context

Il codebase ha già il pattern completo implementato per altri modelli. Si tratta di:
1. Correggere errori nella view (punta ad appunti invece di documenti)
2. Aggiungere un nuovo campo filtro seguendo il pattern esistente

File chiave:
- `app/views/documenti/index.html.erb` — view da correggere
- `app/models/filters/documento.rb` — query filter
- `app/models/filters/documento/fields.rb` — campi filtro
- `app/models/filters/documento/filtering.rb` — UI presenter
- `app/controllers/documenti_controller.rb` — già usa FilterScoped

## Constraints

- **Tech stack**: Rails 8.0.3, seguire pattern esistente
- **Pattern**: Usare esattamente lo stesso approccio di Filters::Cliente
- **Testing**: Minitest con fixtures (no factories)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Seguire pattern Clienti | Consistenza codebase, già testato | — Pending |
| Solo clientable_type | Scope minimo per completare | — Pending |

---
*Last updated: 2026-01-17 after initialization*
