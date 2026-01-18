---
phase: 08-form-views
plan: 02
subsystem: ui
tags: [erb, bem, forms, migration]

# Dependency graph
requires:
  - phase: 08-form-views
    provides: documento-form BEM block CSS infrastructure (plan 01)
provides:
  - Form partials with BEM classes (_form.html.erb, _documento_riga.html.erb)
  - Semantic class structure for form sections and fieldsets
  - No Tailwind utilities on container elements
affects: [09-index-view]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "BEM class migration pattern: section > fieldset > field hierarchy"
    - "Preserve functional classes (cb-tax, handle) while replacing layout classes"

key-files:
  created: []
  modified:
    - app/views/documenti/_form.html.erb
    - app/views/documento_righe/_documento_riga.html.erb

key-decisions:
  - "Preserve cb-tax and cb-tax-fancy classes for Hotwire Combobox functionality"
  - "Preserve handle class for Sortable Stimulus controller"
  - "Keep Tailwind inside inline_fields block and on number_field inputs"

patterns-established:
  - "Form section BEM modifiers: --header, --clientable, --righe"
  - "Form fieldset BEM modifiers: --causale, --numero, --data, --small"
  - "Riga field BEM modifiers: --prezzo for specific field styling"

# Metrics
duration: 6min
completed: 2026-01-18
---

# Phase 8 Plan 2: Form ERB Migration Summary

**Migrated _form.html.erb and _documento_riga.html.erb from Tailwind utilities to BEM classes with 12+ semantic class references**

## Performance

- **Duration:** 6 min
- **Started:** 2026-01-18T15:15:00Z
- **Completed:** 2026-01-18T15:21:00Z
- **Tasks:** 3 (2 migration, 1 verification)
- **Files modified:** 2

## Accomplishments

- Replaced all container/section Tailwind utilities with BEM classes in _form.html.erb
- Replaced all container Tailwind utilities with BEM classes in _documento_riga.html.erb
- Preserved functional classes (cb-tax, cb-tax-fancy, handle) for JavaScript integrations
- Verified ERB syntax valid and Rails environment loads correctly

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate _form.html.erb to BEM classes** - `c98a5041` (refactor)
2. **Task 2: Migrate _documento_riga.html.erb to BEM classes** - `cc7427cb` (refactor)
3. **Task 3: Verify form renders and functions** - verification only, no commit

**Plan metadata:** (to be added after summary commit)

## Files Created/Modified

- `app/views/documenti/_form.html.erb` - 12 BEM class references, 0 container Tailwind
- `app/views/documento_righe/_documento_riga.html.erb` - 7 BEM riga class references, 0 container Tailwind

## Decisions Made

- **Preserve functional classes:** cb-tax, cb-tax-fancy (Hotwire Combobox), handle (Sortable) kept alongside BEM classes
- **Keep Tailwind on inputs:** Number field inputs retain Tailwind for consistent form styling until dedicated input component migration
- **Keep inline_fields block unchanged:** Internal Tailwind for toggle behavior must remain per plan specification

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 8 (Form Views) complete
- Ready for Phase 9 (Index View) migration
- All form partials now use semantic BEM classes
- No blockers

---
*Phase: 08-form-views*
*Completed: 2026-01-18*
