# Requirements: Filter Pattern Documenti

**Defined:** 2026-01-17
**Core Value:** Documenti filtrabili per causale, stato, tipo cliente e anno con UX consistente

## v1 Requirements

### View Fix

- [x] **VIEW-01**: Filter settings punta a documenti_path (non appunti_path)
- [x] **VIEW-02**: filter_type è "documento" (non "appunto")

### ClientableType Filter

- [x] **FILT-01**: Campo clientable_type in Fields con store_accessor e getter/setter
- [x] **FILT-02**: Query in Documento.documenti filtra per clientable_type
- [x] **FILT-03**: FILTER_PARAMS nel controller include clientable_type

### UI Presenter

- [x] **UI-01**: Metodo clientable_types_disponibili in Filtering
- [x] **UI-02**: Metodo show_clientable_types? in Filtering
- [x] **UI-03**: filters_active? include controllo clientable_type

### Verification

- [ ] **VER-01**: UI filtri visibile nella pagina documenti
- [ ] **VER-02**: Filtro clientable_type funziona (filtra correttamente)

## v2 Requirements

(Nessuno - scope minimo per completare)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Intervallo date (da/a) | Anno sufficiente per ora |
| Nuovi filtri oltre clientable_type | Scope limitato |
| Refactoring multi-tenancy | Non in questo milestone |
| Test automatici | Codebase ha bassa copertura, focus su funzionalità |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| VIEW-01 | Phase 1 | Complete |
| VIEW-02 | Phase 1 | Complete |
| FILT-01 | Phase 2 | Complete |
| FILT-02 | Phase 2 | Complete |
| FILT-03 | Phase 2 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| VER-01 | Phase 3 | Pending |
| VER-02 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 10 total
- Mapped to phases: 10
- Unmapped: 0 ✓

---
*Requirements defined: 2026-01-17*
*Last updated: 2026-01-17 after Phase 2 completion*
