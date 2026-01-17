# Roadmap: Filter Pattern Documenti

## Overview

Complete the Filter Pattern for Documenti by fixing view URLs, adding clientable_type filter capability, and verifying functionality. This follows the established pattern already working for Clienti, Appunti, Libri, and Scuole.

## Phases

- [x] **Phase 1: View Fix** - Correct filter URLs pointing to wrong endpoints ✓
- [x] **Phase 2: ClientableType Filter** - Add clientable_type filter with Fields, Query, Controller, and UI ✓
- [ ] **Phase 3: Verification** - Manual verification of filter functionality

## Phase Details

### Phase 1: View Fix
**Goal**: Documenti index page filter settings point to correct endpoints
**Depends on**: Nothing (first phase)
**Requirements**: VIEW-01, VIEW-02
**Plans:** 1 plan
**Success Criteria** (what must be TRUE):
  1. Filter form submits to documenti_path (not appunti_path)
  2. Filter partial receives filter_type "documento" (not "appunto")

Plans:
- [x] 01-01-PLAN.md — Fix filter_url, no_filtering_url, and filter_type in documenti index view ✓

### Phase 2: ClientableType Filter
**Goal**: Users can filter documents by client type (Cliente vs ImportScuola)
**Depends on**: Phase 1
**Requirements**: FILT-01, FILT-02, FILT-03, UI-01, UI-02, UI-03
**Plans:** 4 plans
**Success Criteria** (what must be TRUE):
  1. User can see clientable_type filter options in the filter sidebar
  2. Selecting a clientable_type filters documents to only that client type
  3. Active filter indicator shows when clientable_type is selected
  4. Filter persists correctly through page interactions

Plans:
- [x] 02-01-PLAN.md — Add clientable_type to Fields (store_accessor, getter/setter) ✓
- [x] 02-02-PLAN.md — Add clientable_type query logic in Documento.documenti ✓
- [x] 02-03-PLAN.md — Add clientable_type to FILTER_PARAMS in controller ✓
- [x] 02-04-PLAN.md — Add UI presenter methods in Filtering (depends on 02-01) ✓

### Phase 3: Verification
**Goal**: Confirm all filter functionality works correctly in browser
**Depends on**: Phase 2
**Requirements**: VER-01, VER-02
**Success Criteria** (what must be TRUE):
  1. Filter UI is visible and accessible on documenti index page
  2. Selecting clientable_type correctly filters the document list
  3. All existing filters (causali, statuses, anno) still work
**Plans**: TBD

Plans:
- [ ] 03-01: Manual browser verification of filter functionality

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. View Fix | 1/1 | Complete ✓ | 2026-01-17 |
| 2. ClientableType Filter | 4/4 | Complete ✓ | 2026-01-17 |
| 3. Verification | 0/1 | Not started | - |

---
*Created: 2026-01-17*
