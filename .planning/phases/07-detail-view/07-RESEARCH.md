# Phase 7: Detail View - Research

**Researched:** 2026-01-18
**Domain:** CSS table styling, BEM detail views, responsive data tables
**Confidence:** HIGH

## Summary

This research analyzes the `show.html.erb` detail view (293 lines) to understand the styling requirements for migrating from Tailwind to BEM CSS. The view has three main sections that need BEM treatment:

1. **Document Header** - Title, action buttons, cliente info, status inline-edit
2. **Righe Table** - Complex table with hierarchical grouping by documento derivato
3. **Table Footer** - Totals for copies and amount

The view uses `causale_bg_class`, `causale_border_class`, and `causale_section_bg_class` helper methods from `causali_helper.rb` that return Tailwind classes. These need BEM equivalents using the `--doc-causale-*` custom properties established in Phase 4 and 6.

**Primary recommendation:** Create a `.documento-detail` BEM block for the show page layout, with `.documento-detail__table` for the righe table. Leverage the causale modifier pattern from Phase 6 and create section-level modifiers for the hierarchical document grouping.

## Standard Stack

### Current Tailwind Classes Being Replaced

The `show.html.erb` uses these key Tailwind patterns:

**Layout container:**
```erb
class: "mx-auto md:w-10/12 w-full flex gap-8"
```

**Table structure:**
```erb
class: "min-w-full"              # table
class: "w-full sm:w-1/2"         # col widths
class: "border-b border-gray-300"  # thead border
class: "border-b border-gray-200"  # tbody row borders
class: "border-t-2"              # section headers
```

**Cell styling (responsive hiding):**
```erb
class: "hidden px-3 py-3.5 text-right text-sm sm:table-cell"
class: "py-3.5 pl-4 pr-3 text-left text-sm sm:pl-0"
```

**Footer totals:**
```erb
class: "hidden pl-4 pr-3 pt-4 text-right text-sm font-normal sm:table-cell sm:pl-0"
class: "py-5 pl-3 pr-4 text-right text-sm font-semibold sm:pr-0"
```

**Causale-based section headers (using helper methods):**
```erb
class: ["border-t", causale_border_class(doc.causale), causale_bg_class(doc.causale)]
class: ["border-t", causale_border_class(doc.causale), causale_section_bg_class(doc.causale)]
```

### BEM Translation Table

| Tailwind Class | BEM Property | Value |
|----------------|--------------|-------|
| `min-w-full` | `inline-size` | `100%` |
| `hidden sm:table-cell` | `display` | `none` / `table-cell` at 640px |
| `text-right` | `text-align` | `end` |
| `text-left` | `text-align` | `start` |
| `text-sm` | `font-size` | `var(--text-small)` |
| `font-semibold` | `font-weight` | `600` |
| `font-medium` | `font-weight` | `500` |
| `font-normal` | `font-weight` | `400` |
| `py-5` | `padding-block` | `1.25rem` |
| `py-3.5` | `padding-block` | `0.875rem` |
| `px-3` | `padding-inline` | `0.75rem` |
| `pl-4` | `padding-inline-start` | `1rem` |
| `pr-3` | `padding-inline-end` | `0.75rem` |
| `border-b` | `border-block-end` | `1px solid` |
| `border-t` | `border-block-start` | `1px solid` |
| `border-t-2` | `border-block-start` | `2px solid` |
| `border-gray-300` | `border-color` | `var(--color-ink-light)` |
| `border-gray-200` | `border-color` | `var(--color-ink-lighter)` |

### CSS Variables Needed (extending Phase 6)

From the view analysis, these section-level variables are needed:

```css
/* Section header backgrounds (lighter than card background) */
--doc-causale-section-bg: /* lighter version for nested sections */

/* Example mappings to _global.css tokens */
.documento--ordine-entrata {
  --doc-causale-bg: oklch(var(--lch-blue-lighter));
  --doc-causale-section-bg: oklch(var(--lch-blue-lightest));
  --doc-causale-border: oklch(var(--lch-blue-light));
}
```

## Architecture Patterns

### Recommended BEM Structure

```
.documento-detail                    /* Block: show page container */
  .documento-detail__header          /* Element: page header with actions */
    .documento-detail__title
    .documento-detail__actions
  .documento-detail__cliente         /* Element: cliente info section */
  .documento-detail__meta            /* Element: referente, notes, status */
  .documento-detail__table-container /* Element: flow wrapper for table */
  .documento-detail__table           /* Element: righe table */
    .documento-detail__thead
    .documento-detail__tbody
    .documento-detail__tfoot
  .documento-detail__section         /* Element: derivato section header */
    --derivato                       /* Modifier: first-level derived doc */
    --nipote                         /* Modifier: second-level nested doc */
  .documento-detail__riga            /* Element: single table row */
  .documento-detail__cell            /* Element: table cell */
    --title                          /* Modifier: titolo column */
    --price                          /* Modifier: prezzo column */
    --quantity                       /* Modifier: quantita column */
    --discount                       /* Modifier: sconto column */
    --amount                         /* Modifier: importo column */
    --hidden-mobile                  /* Modifier: hide on mobile */
  .documento-detail__totals          /* Element: footer totals */
    --copies
    --amount
```

### Pattern 1: Responsive Table with Hidden Columns

**What:** Hide less-important columns on mobile, show on desktop.
**When to use:** Tables with more than 3-4 columns that don't fit on small screens.
**Example:**

```css
/* Source: Derived from Tailwind hidden sm:table-cell pattern */
.documento-detail__cell--hidden-mobile {
  display: none;

  @media (min-width: 640px) {
    display: table-cell;
  }
}

.documento-detail__totals-label--hidden-mobile {
  display: none;

  @media (min-width: 640px) {
    display: table-cell;
  }
}

.documento-detail__totals-label--mobile-only {
  display: table-cell;

  @media (min-width: 640px) {
    display: none;
  }
}
```

### Pattern 2: Section Headers with Causale Theming

**What:** Hierarchical document grouping with color-coded section headers.
**When to use:** When displaying derived documents (documenti derivati) within a parent.
**Example:**

```css
/* Source: Pattern from show.html.erb section headers */
.documento-detail__section {
  background-color: var(--doc-causale-bg);
  border-block-start: 1px solid var(--doc-causale-border);
  font-weight: 700;
  padding: 0.5rem 1rem;
}

.documento-detail__section--derivato {
  border-block-start-width: 2px;
}

.documento-detail__section--nipote {
  background-color: var(--doc-causale-section-bg);
  padding-inline-start: 1.5rem;
}
```

### Pattern 3: Column Width Control with colgroup

**What:** Use `<colgroup>` to control column proportions responsively.
**When to use:** When columns need different widths at different breakpoints.
**Example:**

```css
/* Source: Pattern from show.html.erb colgroup */
.documento-detail__col--title {
  width: 100%;

  @media (min-width: 640px) {
    width: 50%;
  }
}

.documento-detail__col--numeric {
  @media (min-width: 640px) {
    width: 12.5%; /* 1/8 of table */
  }
}
```

### Pattern 4: Inline Icon with Section Header

**What:** SVG icon aligned with section header text.
**When to use:** For visual hierarchy indicators (arrows for derivati).
**Example:**

```css
/* Source: Pattern from show.html.erb section headers */
.documento-detail__section-content {
  align-items: center;
  display: flex;
  gap: 0.5rem;
  padding-inline-start: 0.5rem;
}

.documento-detail__section-icon {
  block-size: 1em;
  inline-size: 1em;
  flex-shrink: 0;
}
```

### Anti-Patterns to Avoid

- **Using `display: block` on table elements for mobile:** This breaks the table semantics. Instead, hide columns.
- **Fixed pixel widths on columns:** Use percentages or let content determine width.
- **Inline Tailwind classes on the table itself:** Convert ALL table styling to BEM.
- **Duplicating causale color logic:** Reuse the modifiers from Phase 6.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Causale theming | New color mappings | Phase 6 `.documento--*` modifiers | Already defined, consistent |
| Status badges in table | New badge styles | Phase 5 `.documento-status__badge` | Already built |
| Section backgrounds | Custom colors | `--doc-causale-bg`, `--doc-causale-section-bg` | Token-based theming |
| Responsive hiding | Custom media queries | Consistent 640px breakpoint | Matches Tailwind sm: |
| Table borders | Hardcoded colors | `--color-ink-lighter`, `--color-ink-light` | Design tokens |

## Common Pitfalls

### Pitfall 1: Table Semantic Breakage

**What goes wrong:** Converting table to divs or using `display: block` on `<tr>` elements breaks accessibility.
**Why it happens:** Trying to make the table "more responsive" by changing its display.
**How to avoid:** Keep the `<table>`, `<thead>`, `<tbody>`, `<tfoot>` structure. Hide columns instead of restructuring.
**Warning signs:** Screen readers don't announce table headers; tab order is wrong.

### Pitfall 2: Missing causale Null Handling in Sections

**What goes wrong:** Section headers crash when `doc_derivato.causale` is nil.
**Why it happens:** Not all derived documents have causale assigned.
**How to avoid:** Always use the modifier helper which returns empty string for nil causale.
**Warning signs:** Errors when viewing documents with derivati that lack causale.

### Pitfall 3: Footer Colspan Mismatch

**What goes wrong:** Totals row doesn't span correctly after hiding columns.
**Why it happens:** `colspan="4"` is hardcoded but hidden columns change the visible count.
**How to avoid:** Use `colspan="4"` for desktop (5 columns, label spans 4) but different for mobile.
**Warning signs:** Footer totals label extends past visible columns or doesn't span enough.

### Pitfall 4: Conflicting Section Border Colors

**What goes wrong:** Section borders use different colors than card borders.
**Why it happens:** Multiple helper methods (`causale_border_class` vs card border).
**How to avoid:** Use single `--doc-causale-border` variable for all borders within the documento.
**Warning signs:** Inconsistent border colors between card header and section headers.

### Pitfall 5: Riga Partial Not Updated

**What goes wrong:** Righe rows still use Tailwind classes after detail view is migrated.
**Why it happens:** `_riga.html.erb` partial is rendered separately.
**How to avoid:** Phase 7 should include migrating the riga partial OR explicitly marking it as out-of-scope.
**Warning signs:** Mixed styling in the table body.

## Code Examples

### Detail Page Container

```css
/* Source: Mapped from show.html.erb container */
.documento-detail {
  display: flex;
  flex-direction: column;
  gap: var(--block-space-double);
  inline-size: 100%;
  margin-inline: auto;

  @media (min-width: 768px) {
    inline-size: 83.333333%; /* w-10/12 */
  }
}
```

### Table Base Styles

```css
/* Source: Mapped from show.html.erb table */
.documento-detail__table {
  inline-size: 100%;
}

.documento-detail__thead {
  border-block-end: 1px solid var(--color-ink-light);
}

.documento-detail__th {
  color: var(--color-ink);
  font-size: var(--text-small);
  font-weight: 600;
  padding: 0.875rem 0.75rem;
  text-align: start;
}

.documento-detail__th--right {
  text-align: end;
}

.documento-detail__th--hidden-mobile {
  display: none;

  @media (min-width: 640px) {
    display: table-cell;
  }
}
```

### Riga Row Styles

```css
/* Source: Mapped from _riga.html.erb */
.documento-detail__riga {
  border-block-end: 1px solid var(--color-ink-lighter);
}

.documento-detail__cell {
  font-size: var(--text-small);
  padding: 1.25rem 0.75rem;
}

.documento-detail__cell--title {
  max-inline-size: 0; /* allows truncation */
  padding-inline-start: 1rem;

  @media (min-width: 640px) {
    padding-inline-start: 0;
  }
}

.documento-detail__cell--title-main {
  color: var(--color-ink);
  font-weight: 500;
}

.documento-detail__cell--title-sub {
  color: var(--color-ink-dark);
  margin-block-start: 0.25rem;
  overflow: hidden;
  text-overflow: ellipsis;
}

.documento-detail__cell--numeric {
  color: var(--color-ink-dark);
  text-align: end;
}

.documento-detail__cell--amount {
  color: var(--color-ink);
  font-weight: 500;
  padding-inline-end: 1rem;
  text-align: end;

  @media (min-width: 640px) {
    padding-inline-end: 0;
  }
}

.documento-detail__cell--hidden-mobile {
  display: none;

  @media (min-width: 640px) {
    display: table-cell;
  }
}
```

### Section Header Styles

```css
/* Source: Mapped from show.html.erb derivato headers */
.documento-detail__section {
  background-color: var(--doc-causale-bg);
  border-block-start: 1px solid var(--doc-causale-border);
}

.documento-detail__section td {
  padding: 0.5rem 0.75rem;
}

.documento-detail__section--derivato {
  border-block-start-width: 2px;
}

.documento-detail__section--derivato td {
  font-weight: 700;
}

.documento-detail__section--nipote {
  background-color: var(--doc-causale-section-bg);
}

.documento-detail__section--nipote td {
  font-weight: 600;
  padding-inline-start: 1.5rem;

  @media (min-width: 640px) {
    padding-inline-start: 1.5rem;
  }
}

.documento-detail__section-content {
  align-items: center;
  display: flex;
  gap: 0.5rem;
  padding-inline-start: 0.5rem;
}

.documento-detail__section-icon {
  block-size: 1rem;
  flex-shrink: 0;
  inline-size: 1rem;
}

.documento-detail__section-icon--small {
  block-size: 0.75rem;
  inline-size: 0.75rem;
}

.documento-detail__section-badge {
  background-color: oklch(var(--lch-purple-lighter));
  border-radius: 9999px;
  color: oklch(var(--lch-purple-dark));
  font-size: var(--text-x-small);
  font-weight: 500;
  padding: 0.125rem 0.5rem;
}

.documento-detail__section-link {
  color: oklch(var(--lch-blue-dark));
  font-size: var(--text-x-small);
  text-decoration: underline;
}

.documento-detail__section-link:hover {
  color: oklch(var(--lch-blue-darker));
}
```

### Table Footer Styles

```css
/* Source: Mapped from show.html.erb tfoot */
.documento-detail__tfoot tr {
  /* No bottom border on footer rows */
}

.documento-detail__totals-label {
  color: var(--color-ink-dark);
  font-size: var(--text-small);
  font-weight: 400;
  padding-block-start: 1rem;
  padding-inline: 0.75rem 1rem;
  text-align: end;
}

.documento-detail__totals-label--bold {
  color: var(--color-ink);
  font-weight: 600;
}

.documento-detail__totals-value {
  color: var(--color-ink-dark);
  font-size: var(--text-small);
  padding-block-start: 1rem;
  padding-inline: 0.75rem;
  text-align: end;
}

.documento-detail__totals-value--bold {
  color: var(--color-ink);
  font-weight: 600;
}

@media (min-width: 640px) {
  .documento-detail__totals-label {
    padding-inline-start: 0;
  }

  .documento-detail__totals-value {
    padding-inline-end: 0;
  }
}
```

### Adding Section-Level Causale Background

Extend the Phase 6 causale modifiers to include section backgrounds:

```css
/* Source: Extension of Phase 6 causale theming */
.documento--ordine-entrata {
  --doc-causale-bg: oklch(var(--lch-blue-lighter));
  --doc-causale-section-bg: oklch(var(--lch-blue-lightest));
  --doc-causale-text: oklch(var(--lch-blue-dark));
  --doc-causale-border: oklch(var(--lch-blue-light));
}

.documento--ordine-uscita {
  --doc-causale-bg: oklch(var(--lch-violet-lighter));
  --doc-causale-section-bg: oklch(var(--lch-violet-lightest));
  --doc-causale-text: oklch(var(--lch-violet-dark));
  --doc-causale-border: oklch(var(--lch-violet-light));
}

.documento--vendita-entrata {
  --doc-causale-bg: oklch(var(--lch-green-lighter));
  --doc-causale-section-bg: oklch(var(--lch-green-lightest));
  --doc-causale-text: oklch(var(--lch-green-dark));
  --doc-causale-border: oklch(var(--lch-green-light));
}

.documento--vendita-uscita {
  --doc-causale-bg: oklch(var(--lch-red-lighter));
  --doc-causale-section-bg: oklch(var(--lch-red-lightest));
  --doc-causale-text: oklch(var(--lch-red-dark));
  --doc-causale-border: oklch(var(--lch-red-light));
}

.documento--carico-entrata {
  --doc-causale-bg: oklch(var(--lch-yellow-lighter));
  --doc-causale-section-bg: oklch(var(--lch-yellow-lightest));
  --doc-causale-text: oklch(var(--lch-yellow-dark));
  --doc-causale-border: oklch(var(--lch-yellow-light));
}

.documento--carico-uscita {
  --doc-causale-bg: oklch(var(--lch-uncolor-lighter));
  --doc-causale-section-bg: oklch(var(--lch-uncolor-lightest));
  --doc-causale-text: oklch(var(--lch-uncolor-dark));
  --doc-causale-border: oklch(var(--lch-uncolor-light));
}
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Tailwind responsive utilities | BEM with media queries | More maintainable |
| Helper returning Tailwind class | Helper returning BEM modifier | Cleaner separation |
| Inline colspan logic | Consistent BEM classes | Easier to modify |

**Responsive table best practices (2025-2026):**
- Use "hidden columns" pattern rather than "stacked rows" to preserve table semantics
- Keep `<thead>`, `<tbody>`, `<tfoot>` structure for accessibility
- Use `@media (min-width: 640px)` breakpoint for consistency with existing patterns

## Open Questions

1. **Riga partial migration scope**
   - What we know: `_riga.html.erb` (31 lines) uses Tailwind classes
   - What's unclear: Should it be migrated in Phase 7 or separate?
   - Recommendation: Include riga partial in Phase 7 since it's integral to the detail table

2. **Heading component (`Heading::WithActionsComponent`)**
   - What we know: The header uses a ViewComponent for layout
   - What's unclear: Should the component be modified or just its wrapper styled?
   - Recommendation: Wrap the component output in `.documento-detail__header`, leave component unchanged

3. **Inline edit section (`shared/inline_edit`)**
   - What we know: Status editing uses a shared partial
   - What's unclear: Should inline_edit be styled via documento-detail or left as-is?
   - Recommendation: Keep inline_edit partial unchanged; it's used elsewhere

4. **Scroll-to buttons for long tables**
   - What we know: View has conditional scroll buttons for tables > 15/20 rows
   - What's unclear: Should these use BEM classes or stay with tax_button component?
   - Recommendation: Leave as tax_button component; focus on table styling only

## Riga Partial Analysis

The `_riga.html.erb` partial (31 lines) renders a single table row with this structure:

```erb
<tr class="border-b border-gray-200">
  <td class="max-w-0 py-5 pl-4 pr-3 text-sm sm:pl-0">
    <div class="font-medium text-gray-900 hover:font-bold">
      <%= link_to riga.libro&.titolo, libro_path(riga.libro) %>
    </div>
    <div class="mt-1 truncate text-gray-500">
      <%= riga.libro&.codice_isbn %>
    </div>
  </td>
  <td class="hidden px-3 py-5 text-right text-sm text-gray-500 sm:table-cell">
    <%= number_to_currency riga.prezzo_cents/100.0, locale: :it %>
  </td>
  <td class="px-3 py-5 text-right text-sm text-gray-500">
    <%= riga.quantita %>
  </td>
  <td class="hidden px-3 py-5 text-right text-sm text-gray-500 sm:table-cell">
    <%= riga.sconto.nil? ? '' : "#{riga.sconto} %" %>
  </td>
  <td class="py-5 pl-3 pr-4 text-right text-sm font-medium text-gray-900 sm:pr-0">
    <%= number_to_currency riga.importo, locale: :it %>
  </td>
</tr>
```

**BEM equivalent:**
```erb
<tr class="documento-detail__riga">
  <td class="documento-detail__cell documento-detail__cell--title">
    <div class="documento-detail__cell--title-main">
      <%= link_to riga.libro&.titolo, libro_path(riga.libro) %>
    </div>
    <div class="documento-detail__cell--title-sub">
      <%= riga.libro&.codice_isbn %>
    </div>
  </td>
  <td class="documento-detail__cell documento-detail__cell--numeric documento-detail__cell--hidden-mobile">
    <%= number_to_currency riga.prezzo_cents/100.0, locale: :it %>
  </td>
  <td class="documento-detail__cell documento-detail__cell--numeric">
    <%= riga.quantita %>
  </td>
  <td class="documento-detail__cell documento-detail__cell--numeric documento-detail__cell--hidden-mobile">
    <%= riga.sconto.nil? ? '' : "#{riga.sconto} %" %>
  </td>
  <td class="documento-detail__cell documento-detail__cell--amount">
    <%= number_to_currency riga.importo, locale: :it %>
  </td>
</tr>
```

## Sources

### Primary (HIGH confidence)
- `/home/paolotax/rails_2023/prova/app/views/documenti/show.html.erb` - Detail view template (293 lines)
- `/home/paolotax/rails_2023/prova/app/views/righe/_riga.html.erb` - Riga partial (31 lines)
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/documenti.css` - Phase 4-6 infrastructure (419 lines)
- `/home/paolotax/rails_2023/prova/app/helpers/causali_helper.rb` - Causale color helper methods
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/_global.css` - Design tokens

### Secondary (HIGH confidence)
- `/home/paolotax/rails_2023/prova/.planning/phases/06-document-card/06-RESEARCH.md` - Causale modifier patterns
- `/home/paolotax/rails_2023/prova/.planning/phases/05-status-badges/05-RESEARCH.md` - Badge patterns
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/cards.css` - BEM reference patterns

### Tertiary (MEDIUM confidence)
- [Smashing Magazine - Accessible Responsive Tables](https://www.smashingmagazine.com/2022/12/accessible-front-end-patterns-responsive-tables-part1/) - Responsive table patterns
- [618media - HTML Tables in Responsive Design](https://618media.com/en/blog/html-tables-in-responsive-design/) - Modern table practices

## Metadata

**Confidence breakdown:**
- Detail view structure: HIGH - Direct code analysis
- Table styling patterns: HIGH - Clear Tailwind mapping
- Causale theming: HIGH - Building on Phase 6 patterns
- Responsive behavior: HIGH - Established 640px breakpoint
- Riga partial scope: MEDIUM - Judgment call on boundaries

**Research date:** 2026-01-18
**Valid until:** 30 days (stable domain, internal codebase patterns)
