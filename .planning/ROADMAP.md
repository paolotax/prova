# Roadmap: Documenti CSS Refactoring

**Milestone:** v1.1
**Created:** 2026-01-18
**Phases:** 6 (4-9)
**Requirements:** 20 mapped

## Overview

This roadmap migrates the documenti views from inline Tailwind utilities to semantic BEM CSS. Phases follow natural dependencies: foundation CSS first, then reusable components (badges), then primary components (cards), then consuming views (detail, form, index). Each phase delivers testable, observable behavior.

---

## Phase 4: Foundation

**Goal:** Establish CSS infrastructure with layer ordering and design tokens before any view changes.

**Dependencies:** None (first phase of v1.1)

**Requirements:**
- FOUND-01: Create `app/assets/stylesheets/documenti.css` with `@layer components` structure
- FOUND-02: Define CSS custom properties for documento theming (colors, spacing, borders)
- FOUND-03: Establish BEM naming conventions matching `cards.css` patterns

**Plans:** 1 plan

Plans:
- [x] 04-01-css-infrastructure-PLAN.md - Create documenti.css with @layer wrapper, design tokens, and BEM documentation

**Success Criteria:**
1. `documenti.css` file exists with `@layer components` wrapper
2. CSS custom properties defined for documento colors, spacing, and borders
3. BEM naming convention documented in file comments matching cards.css patterns
4. File loads without errors in browser (no CSS syntax issues)

---

## Phase 5: Status Badges

**Goal:** Create reusable status badge component for use across all documento views.

**Dependencies:** Phase 4 (requires CSS infrastructure)

**Requirements:**
- BADGE-01: Create `.documento-status` block for status/payment indicators
- BADGE-02: Add modifiers for states (`--pagato`, `--consegnato`, `--incompleto`, `--bozza`)
- BADGE-03: Refactor `_status_badges.html.erb` to use semantic classes

**Plans:** 1 plan

Plans:
- [x] 05-01-status-badges-PLAN.md - Add status badge CSS and refactor ERB partial to use BEM classes

**Success Criteria:**
1. Status badges display correct colors for each state (pagato=green, bozza=gray, incompleto=amber)
2. `_status_badges.html.erb` contains no Tailwind utility classes
3. Badge styles render correctly in both light and dark themes
4. Badges maintain consistent size and alignment across views

---

## Phase 6: Document Card

**Goal:** Migrate primary documento card component used in list views.

**Dependencies:** Phase 5 (badges used in cards)

**Requirements:**
- CARD-01: Create `.documento` block for list item card in `_documento.html.erb`
- CARD-02: Define `.documento__header`, `__body`, `__footer` elements
- CARD-03: Add responsive behavior (mobile-first with sm: breakpoint)
- CARD-04: Handle causale-based color variations via CSS custom properties
- CARD-05: Refactor `_documento_card.html.erb` to use `.documento` block

**Plans:** 1 plan

Plans:
- [x] 06-01-document-card-PLAN.md - Add documento card BEM CSS and refactor both card partials

**Success Criteria:**
1. Documento cards display with header, body, and footer sections clearly visible
2. Cards respond correctly at mobile (<640px) and desktop (>640px) breakpoints
3. Different causale types show appropriate color accents
4. `_documento.html.erb` and `_documento_card.html.erb` contain no Tailwind utility classes
5. Card hover and selection states work correctly

---

## Phase 7: Detail View

**Goal:** Migrate show.html.erb detail view with table layout for righe.

**Dependencies:** Phase 5 (badges used in detail view)

**Requirements:**
- DETAIL-01: Create `.documento-detail` block for `show.html.erb`
- DETAIL-02: Style table layout for righe (line items)
- DETAIL-03: Style derived documents (documenti derivati) sections
- DETAIL-04: Handle responsive table behavior

**Success Criteria:**
1. Detail view displays documento header, client info, and righe table
2. Righe table is readable on mobile (horizontal scroll or stacked layout)
3. Derived documents section displays correctly with links to child documents
4. `show.html.erb` contains no Tailwind utility classes
5. Print styles maintain readability

---

## Phase 8: Form Views

**Goal:** Migrate form editing views with section-based layout.

**Dependencies:** Phase 5 (badges may appear in form context)

**Requirements:**
- FORM-01: Create `.documento-form` block for `_form.html.erb`
- FORM-02: Style form sections (header, clientable, righe)
- FORM-03: Style inline edit components

**Success Criteria:**
1. Form displays with clear section boundaries (header, client, line items)
2. Inline edit components (date pickers, selects) maintain usability
3. Form validation errors display correctly with semantic styles
4. `_form.html.erb` contains no Tailwind utility classes

---

## Phase 9: Index View

**Goal:** Complete migration by updating index view to use documento component classes.

**Dependencies:** Phase 6 (index uses card components)

**Requirements:**
- INDEX-01: Update `index.html.erb` to use documento classes
- INDEX-02: Remove remaining Tailwind utilities from index

**Success Criteria:**
1. Index view displays documento list using semantic card classes
2. `index.html.erb` contains no Tailwind utility classes
3. Filter integration continues to work (chips, search, results)
4. Empty state displays correctly with semantic styling

---

## Progress

| Phase | Name | Requirements | Status |
|-------|------|--------------|--------|
| 4 | Foundation | FOUND-01, FOUND-02, FOUND-03 | Complete |
| 5 | Status Badges | BADGE-01, BADGE-02, BADGE-03 | Complete |
| 6 | Document Card | CARD-01, CARD-02, CARD-03, CARD-04, CARD-05 | Complete |
| 7 | Detail View | DETAIL-01, DETAIL-02, DETAIL-03, DETAIL-04 | Pending |
| 8 | Form Views | FORM-01, FORM-02, FORM-03 | Pending |
| 9 | Index View | INDEX-01, INDEX-02 | Pending |

**Coverage:** 20/20 requirements mapped

---
*Created: 2026-01-18*
*Milestone: v1.1 Documenti CSS Refactoring*
