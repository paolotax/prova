# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-18)

**Core value:** Le views documenti devono usare classi BEM semantiche invece di utility Tailwind
**Current focus:** Phase 9 - Index View (next)

## Current Position

Phase: 8 of 9 (Form Views)
Plan: 2 of 2 complete
Status: Phase complete
Last activity: 2026-01-18 - Completed 08-02-PLAN.md

Progress: [#######   ] 88% - Phase 8 complete (7/8 plans)

## Milestone Progress

| Phase | Name | Status |
|-------|------|--------|
| 4 | Foundation | Complete |
| 5 | Status Badges | Complete |
| 6 | Document Card | Complete |
| 7 | Detail View | Complete |
| 8 | Form Views | Complete |
| 9 | Index View | Pending |

## Performance Metrics

**Milestone v1.0 (archived):**
- Total plans completed: 6
- Total phases: 3
- Timeline: Same-day completion (2026-01-17)

**Milestone v1.1:**
- Phases: 6 (phases 4-9)
- Requirements: 20
- Started: 2026-01-18
- Plans completed: 7 (04-01, 05-01, 06-01, 07-01, 07-02, 08-01, 08-02)

## Accumulated Context

### Decisions

All decisions logged in PROJECT.md Key Decisions table.

Key v1.1 decisions:
- Single `documenti.css` file (not multiple partials)
- BEM naming following existing cards.css patterns
- Simplified styling (not pixel-perfect Tailwind match)

Phase 4-01 decisions:
- Used cards.css as structural template
- Defined status colors using OKLCH from _global.css
- Added dark mode stub following cards.css pattern

Phase 5-01 decisions:
- Single .documento-status__badge element with state modifiers (not separate badge types)
- Added --pending and --negative modifiers for future extensibility
- Used relative units (1em) for icon sizing

Phase 6-01 decisions:
- Used CSS custom properties for causale theming (--doc-causale-bg, --doc-causale-text, --doc-causale-border)
- Preserved checkbox and link Tailwind styling per plan specification
- Single .documento--selected modifier handles both main and compact variant selection

Phase 7-01 decisions:
- CSS custom property inheritance for section theming (--doc-causale-bg, --doc-causale-border)
- Added --hidden-mobile modifier pattern for responsive column hiding
- Print styles show all hidden columns

Phase 7-02 decisions:
- Preserved inline_edit content styling (Tailwind inside shared component block)
- Preserved tax_button wrapper styling (component has own system)

Phase 8-01 decisions:
- Form container uses display: contents to avoid extra wrapper
- Section modifiers (--header, --clientable, --righe) provide distinct layouts

Phase 8-02 decisions:
- Preserve cb-tax, cb-tax-fancy, handle classes for JS integrations
- Keep Tailwind on number_field inputs until dedicated input migration
- Keep inline_fields block internal Tailwind unchanged

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: 2026-01-18 15:21
Stopped at: Completed 08-02-PLAN.md
Resume file: None
Next: Execute Phase 9 (Index View)

---
*Created: 2026-01-17*
*Updated: 2026-01-18 - Phase 8 complete*
