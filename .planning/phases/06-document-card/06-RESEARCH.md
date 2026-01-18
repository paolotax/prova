# Phase 6: Document Card - Research

**Researched:** 2026-01-18
**Domain:** Rails ERB view components, BEM CSS architecture, Tailwind-to-CSS migration
**Confidence:** HIGH

## Summary

This research analyzes the existing `_documento.html.erb` (107 lines) and `_documento_card.html.erb` (35 lines) partials to understand how to migrate them to BEM CSS using the infrastructure established in Phase 4-5.

The main card (`_documento.html.erb`) has a clear three-section structure: header (causale info, checkbox, cliente), expandable body (righe list), and footer (status badges, avatars, totals). The card uses causale-based color theming through helper methods that return Tailwind classes. The alternative card (`_documento_card.html.erb`) is a simpler link-based card used in different contexts.

**Primary recommendation:** Create a `.documento` BEM block with `__header`, `__body`, `__footer` elements, using CSS custom properties for causale-based theming that map to the existing `--lch-*` design tokens.

## Standard Stack

### Core (Already Available)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails 8 ERB | 8.0.3 | View templates | Project standard |
| CSS @layer | Native | Style organization | Already in cards.css |
| CSS Custom Properties | Native | Theming/colors | Established in _global.css |

### Supporting (Already Available)
| Library | Purpose | When to Use |
|---------|---------|-------------|
| `class_names` helper | Conditional CSS classes | Toggle modifiers based on state |
| `tag.div/header/footer` | Semantic HTML helpers | Structure card sections |
| `dom_id` | Unique element IDs | Turbo frame targeting |

### Design Tokens Available
| Token Family | Values | Maps To |
|--------------|--------|---------|
| `--lch-blue-*` | lighter, light, medium, dark | ordine/entrata |
| `--lch-violet-*` | lighter, light, medium, dark | ordine/uscita (indigo equivalent) |
| `--lch-green-*` | lighter, light, medium, dark | vendita/entrata (emerald equivalent) |
| `--lch-red-*` | lighter, light, medium, dark | vendita/uscita (rose equivalent) |
| `--lch-yellow-*` | lighter, light, medium, dark | carico/entrata (amber equivalent) |
| `--lch-uncolor-*` | lighter, light, medium, dark | carico/uscita (orange equivalent) |

## Architecture Patterns

### Recommended Card Structure
```
.documento                    /* Block: the card container */
  .documento__header          /* Element: causale, checkbox, cliente info */
    .documento__checkbox
    .documento__title         /* causale + numero/data */
    .documento__cliente       /* clientable partial container */
    .documento__actions       /* edit, print, expand buttons */
  .documento__body            /* Element: expandable righe list */
    .documento__righe         /* ul for riga_item partials */
  .documento__footer          /* Element: badges, avatars, totals */
    .documento__badges        /* status_badges partial container */
    .documento__avatars       /* StackedLibriComponent container */
    .documento__totals        /* copies and amount */
```

### Pattern 1: Causale-Based Theming via CSS Custom Properties

**What:** Set `--doc-causale-*` variables based on causale type, letting CSS handle colors.

**When to use:** For all documento card styling that varies by causale.

**Example:**
```css
/* Source: Pattern from cards.css --card-color system */
.documento {
  --doc-causale-bg: oklch(var(--lch-ink-lightest));
  --doc-causale-text: var(--color-ink-dark);
  --doc-causale-border: var(--color-ink-lighter);
}

.documento--ordine-entrata {
  --doc-causale-bg: oklch(var(--lch-blue-lighter));
  --doc-causale-text: oklch(var(--lch-blue-dark));
  --doc-causale-border: oklch(var(--lch-blue-light));
}

.documento--vendita-entrata {
  --doc-causale-bg: oklch(var(--lch-green-lighter));
  --doc-causale-text: oklch(var(--lch-green-dark));
  --doc-causale-border: oklch(var(--lch-green-light));
}
```

### Pattern 2: Helper Method for BEM Modifier

**What:** Update `documento_header_bg_classes` helper to return BEM modifier instead of Tailwind class.

**When to use:** In the ERB partial to add the correct modifier class.

**Example:**
```ruby
# Source: Derived from existing causali_helper.rb pattern
def documento_causale_modifier(documento)
  return "" unless documento.causale

  tipo = documento.causale.tipo_movimento
  mov = documento.causale.movimento

  "documento--#{tipo}-#{mov}"  # e.g., "documento--ordine-entrata"
end
```

### Pattern 3: Responsive Grid Layout

**What:** Use CSS Grid with media query for footer totals layout.

**When to use:** Footer section needs different column spans on mobile vs desktop.

**Example:**
```css
/* Source: Pattern from existing _documento.html.erb Tailwind */
.documento__footer {
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 0.5rem;
}

@media (min-width: 640px) {
  .documento__footer {
    grid-template-columns: repeat(8, 1fr);
  }
}

.documento__badges { grid-column: 1 / -1; }
.documento__avatars { grid-column: span 3; }
.documento__copies { grid-column: span 1; text-align: right; }
.documento__amount { grid-column: span 2; text-align: right; }

@media (min-width: 640px) {
  .documento__avatars { grid-column: span 2; }
  .documento__copies { grid-column-start: 5; }
  .documento__amount { grid-column-start: 7; }
}
```

### Anti-Patterns to Avoid

- **Inline Tailwind classes with BEM classes:** Don't mix `class="documento__header bg-blue-100"`. Either all BEM or all Tailwind per element.
- **Hardcoded colors in CSS:** Use `--lch-*` tokens exclusively for causale colors.
- **Duplicating status badge styles:** Reuse `.documento-status` from Phase 5, don't redefine.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Causale colors | Manual color values | `--lch-*` design tokens | Consistency, dark mode support |
| Status badges | New badge component | `.documento-status__badge` from Phase 5 | Already built and tested |
| Expandable content | Custom JS accordion | `tax-reveal` Stimulus controller | Already exists, handles toggle |
| Checkbox styling | Custom checkbox CSS | Existing form styles | Project consistency |

## Common Pitfalls

### Pitfall 1: Tailwind Breakpoint Mismatch

**What goes wrong:** Tailwind `sm:` breakpoint is 640px, but CSS might use different value.
**Why it happens:** Forgetting to check Tailwind config for exact breakpoint values.
**How to avoid:** Always use `@media (min-width: 640px)` for `sm:` equivalents.
**Warning signs:** Layout shifts at different viewport widths than before.

### Pitfall 2: Missing Causale Null Check

**What goes wrong:** Card crashes when `documento.causale` is nil.
**Why it happens:** Not all documents have a causale assigned.
**How to avoid:** Always provide fallback: `documento--ordine-entrata` or neutral gray.
**Warning signs:** Errors in log when viewing documents without causale.

### Pitfall 3: Z-Index Conflicts with Expandable Body

**What goes wrong:** Expanded righe list overlaps other cards.
**Why it happens:** The `tax-reveal` controller toggles visibility but doesn't handle stacking.
**How to avoid:** Keep `.documento__body` in normal flow; use `position: relative` on card.
**Warning signs:** Visual overlap when expanding multiple cards.

### Pitfall 4: Grid Column Start vs Span Confusion

**What goes wrong:** Footer totals misaligned on desktop.
**Why it happens:** Original uses both `col-start-*` and `col-span-*` Tailwind utilities.
**How to avoid:** Map carefully:
- `col-start-4` = `grid-column-start: 4`
- `col-span-2` = `grid-column: span 2`
- `col-start-5 col-span-1` = `grid-column: 5 / 6`
**Warning signs:** Numbers don't align to right edge on desktop.

## Code Examples

### Tailwind-to-BEM Mapping for Header

Current Tailwind:
```erb
<%= tag.header class: ["px-4 py-2 flex items-center justify-between border rounded-tl-lg rounded-tr-lg", documento_header_bg_classes(documento)] do %>
```

BEM Equivalent:
```erb
<%= tag.header class: class_names("documento__header", documento_causale_modifier(documento)) do %>
```

CSS:
```css
/* Source: Mapped from Tailwind utility analysis */
.documento__header {
  align-items: center;
  background-color: var(--doc-causale-bg);
  border: var(--doc-border);
  border-radius: var(--doc-border-radius) var(--doc-border-radius) 0 0;
  display: flex;
  gap: var(--doc-gap);
  justify-content: space-between;
  padding: 0.5rem 1rem;
}
```

### Tailwind-to-BEM Mapping for Footer Grid

Current Tailwind:
```erb
<%= tag.footer class: ["p-4 border border-t-0 border-gray-300 mb-4 last:rounded-b-lg last:shadow-md grid grid-cols-6 sm:grid-cols-8", documento_footer_bg_classes(documento)] do %>
```

BEM Equivalent:
```erb
<%= tag.footer class: class_names("documento__footer", documento_causale_modifier(documento)) do %>
```

CSS:
```css
/* Source: Mapped from Tailwind utility analysis */
.documento__footer {
  background-color: var(--doc-causale-bg);
  border: var(--doc-border);
  border-top: none;
  display: grid;
  gap: 0.5rem;
  grid-template-columns: repeat(6, 1fr);
  margin-bottom: 1rem;
  padding: 1rem;

  &:last-child {
    border-radius: 0 0 var(--doc-border-radius) var(--doc-border-radius);
    box-shadow: var(--shadow);
  }
}

@media (min-width: 640px) {
  .documento__footer {
    gap: 1rem;
    grid-template-columns: repeat(8, 1fr);
  }
}
```

### Causale Modifier Classes

```css
/* Source: Mapped from causali_helper.rb logic to --lch-* tokens */

/* Default/fallback (no causale) */
.documento {
  --doc-causale-bg: var(--color-ink-lightest);
  --doc-causale-text: var(--color-ink-dark);
  --doc-causale-border: var(--color-ink-lighter);
}

/* Ordine + Entrata (blue-100 equivalent) */
.documento--ordine-entrata {
  --doc-causale-bg: oklch(var(--lch-blue-lighter));
  --doc-causale-text: oklch(var(--lch-blue-dark));
  --doc-causale-border: oklch(var(--lch-blue-light));
}

/* Ordine + Uscita (indigo-100 equivalent) */
.documento--ordine-uscita {
  --doc-causale-bg: oklch(var(--lch-violet-lighter));
  --doc-causale-text: oklch(var(--lch-violet-dark));
  --doc-causale-border: oklch(var(--lch-violet-light));
}

/* Vendita + Entrata (emerald-100 equivalent) */
.documento--vendita-entrata {
  --doc-causale-bg: oklch(var(--lch-green-lighter));
  --doc-causale-text: oklch(var(--lch-green-dark));
  --doc-causale-border: oklch(var(--lch-green-light));
}

/* Vendita + Uscita (rose-100 equivalent) */
.documento--vendita-uscita {
  --doc-causale-bg: oklch(var(--lch-red-lighter));
  --doc-causale-text: oklch(var(--lch-red-dark));
  --doc-causale-border: oklch(var(--lch-red-light));
}

/* Carico + Entrata (amber-100 equivalent) */
.documento--carico-entrata {
  --doc-causale-bg: oklch(var(--lch-yellow-lighter));
  --doc-causale-text: oklch(var(--lch-yellow-dark));
  --doc-causale-border: oklch(var(--lch-yellow-light));
}

/* Carico + Uscita (orange-100 equivalent) */
.documento--carico-uscita {
  --doc-causale-bg: oklch(var(--lch-uncolor-lighter));
  --doc-causale-text: oklch(var(--lch-uncolor-dark));
  --doc-causale-border: oklch(var(--lch-uncolor-light));
}
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Tailwind utility classes per element | BEM block with CSS custom properties | Maintainable, themeable |
| Helper returning Tailwind class | Helper returning BEM modifier | Cleaner separation |
| Inline responsive utilities | CSS media queries in stylesheet | Consistent breakpoints |

**Key insight:** The `cards.css` pattern of using `--card-color` custom property cascading to child elements is the model to follow for `.documento` causale theming.

## Differences Between _documento.html.erb and _documento_card.html.erb

| Aspect | _documento.html.erb | _documento_card.html.erb |
|--------|---------------------|--------------------------|
| **Purpose** | Main list item card | Simple link card |
| **Lines** | 107 | 35 |
| **Structure** | header + body + footer | Single div |
| **Checkbox** | Yes (bulk actions) | No |
| **Expandable** | Yes (righe list) | No |
| **Actions** | Edit, print, expand buttons | No |
| **Status badges** | Phase 5 component | Inline text |
| **Avatars** | StackedLibriComponent | No |
| **Selection state** | `@documento == documento` highlight | `@documento == documento` highlight |

**Recommendation:** Focus Phase 6 on `_documento.html.erb`. The simpler `_documento_card.html.erb` can either:
1. Be deprecated in favor of the main card with a "compact" modifier
2. Be migrated separately as a `.documento--compact` variant

## Open Questions

1. **Checkbox styling scope**
   - What we know: Current checkbox uses extensive Tailwind classes
   - What's unclear: Should it use existing form checkbox styles or documento-specific?
   - Recommendation: Keep checkbox Tailwind for now, migrate in a separate task

2. **Action buttons (tax_button component)**
   - What we know: Uses custom `component` helper with colors
   - What's unclear: Should these buttons be migrated to BEM or left as-is?
   - Recommendation: Leave as-is; they're a separate component system

3. **Nested partials (clientables, righe)**
   - What we know: Card renders several nested partials with their own Tailwind
   - What's unclear: Should those be migrated in this phase?
   - Recommendation: Out of scope; focus on the card container only

## Sources

### Primary (HIGH confidence)
- `/home/paolotax/rails_2023/prova/app/views/documenti/_documento.html.erb` - Main card template (107 lines)
- `/home/paolotax/rails_2023/prova/app/views/documenti/_documento_card.html.erb` - Alternative card (35 lines)
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/documenti.css` - Phase 4-5 infrastructure
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/cards.css` - Reference BEM patterns
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/_global.css` - Design tokens (--lch-* colors)
- `/home/paolotax/rails_2023/prova/app/helpers/causali_helper.rb` - Causale color logic

### Secondary (MEDIUM confidence)
- `/home/paolotax/rails_2023/prova/app/helpers/documenti_helper.rb` - Header/footer helper methods
- `/home/paolotax/rails_2023/prova/app/views/documenti/_status_badges.html.erb` - Phase 5 badge usage

## Metadata

**Confidence breakdown:**
- Card structure analysis: HIGH - Direct code inspection
- Tailwind-to-CSS mapping: HIGH - Straightforward utility translation
- Causale color mapping: HIGH - Clear logic in helper + available tokens
- Grid layout conversion: HIGH - Well-documented Tailwind behavior
- Nested component scope: MEDIUM - Judgment call on boundaries

**Research date:** 2026-01-18
**Valid until:** 30 days (stable domain, no external dependencies)
