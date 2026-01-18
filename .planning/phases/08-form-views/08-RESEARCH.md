# Phase 8: Form Views - Research

**Researched:** 2026-01-18
**Domain:** CSS form styling, BEM form components, section-based layouts
**Confidence:** HIGH

## Summary

This research analyzes the `_form.html.erb` (100 lines) and related form partials to understand the styling requirements for migrating from Tailwind to BEM CSS. The form has a clear section-based structure:

1. **Header Section** - Causale combobox, numero, data, and inline_fields for status/payment
2. **Clientable Section** - Customer selection via TaxSelectClientableComponent, referente, notes
3. **Righe Section** - Dynamic list of documento_righe with sortable behavior
4. **Actions** - Add riga button and submit button

The form already uses `class="contents"` on the form element (enabling grid layout inheritance) and relies on several existing Stimulus controllers (`tax-combobox-causale`, `tax-combobox-libro`, `sortable`). Key constraint from prior decisions: preserve inline_edit and tax_button wrapper styling (these components have their own systems).

**Primary recommendation:** Create a `.documento-form` BEM block with `__section`, `__fieldset`, `__riga` elements. Use the existing `--doc-*` custom properties for consistent theming, and create form-specific elements that complement the Phase 6-7 patterns.

## Standard Stack

### Current Tailwind Classes in _form.html.erb

**Form container:**
```erb
form_with(model: documento, class: "contents")
```

**Section containers:**
```erb
class: "grid grid-cols-4 sm:grid-cols-8 my-4 px-6 pb-5 bg-gray-200 gap-4 border rounded-lg"
class: "col-span-4 mb-4 px-6 pb-5 bg-gray-200 border rounded-lg flex flex-col"
class: "col-span-4"  # righe section
```

**Fieldsets:**
```erb
class: "col-span-4 my-5 cb-tax flex flex-col"        # causale combobox
class: "col-span-2 my-5 flex flex-col"               # numero
class: "col-span-2 my-5"                              # data
class: "my-2"                                          # referente, notes
class: "my-5 cb-tax-fancy flex flex-col gap-2"       # clientable selection
```

**Error display:**
```erb
class: "bg-red-50 text-red-500 px-3 py-2 font-medium rounded-lg mt-3"
```

**Submit button:**
```erb
class: "rounded-lg py-3 px-5 bg-blue-600 text-white inline-block font-medium cursor-pointer"
```

### Current Tailwind Classes in _documento_riga.html.erb

**Riga container:**
```erb
class: "mb-2 bg-white px-4 py-2.5 border rounded-lg inline-block grid grid-cols-4 sm:grid-cols-8 gap-4 items-end"
```

**Fieldsets:**
```erb
class: "col-span-4 sm:col-span-4 flex items-center"  # libro combobox
class: "col-span-1 flex flex-col justify-between items-center"  # numeric fields
class: "col-start-2 sm:col-start-auto col-span-1"   # prezzo (mobile positioning)
class: "col-span-1 flex justify-center items-center" # delete button
```

**Input styling:**
```erb
class: "text-right [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none w-full rounded-md border-0 py-2 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-gray-600"
```

**Drag handle:**
```erb
class: "handle cursor-move flex-0 pr-4"
```

**Delete button:**
```erb
class: "mb-1.5 mx-2 h-7 w-7 flex justify-center items-center text-center rounded-full shadow-sm bg-red-600 text-white hover:bg-red-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-red-600"
```

### BEM Translation Table

| Tailwind Class | BEM Property | Value |
|----------------|--------------|-------|
| `grid grid-cols-4` | `display: grid; grid-template-columns` | `repeat(4, 1fr)` |
| `sm:grid-cols-8` | `@media (min-width: 640px)` | `repeat(8, 1fr)` |
| `col-span-4` | `grid-column` | `span 4` |
| `col-span-2` | `grid-column` | `span 2` |
| `col-span-1` | `grid-column` | `span 1` |
| `col-start-2` | `grid-column-start` | `2` |
| `gap-4` | `gap` | `1rem` |
| `my-4` | `margin-block` | `1rem` |
| `my-5` | `margin-block` | `1.25rem` |
| `my-2` | `margin-block` | `0.5rem` |
| `mb-2` | `margin-block-end` | `0.5rem` |
| `px-6` | `padding-inline` | `1.5rem` |
| `px-4` | `padding-inline` | `1rem` |
| `pb-5` | `padding-block-end` | `1.25rem` |
| `py-2.5` | `padding-block` | `0.625rem` |
| `bg-gray-200` | `background-color` | `var(--color-ink-lighter)` |
| `bg-white` | `background-color` | `var(--color-canvas)` |
| `bg-red-50` | `background-color` | `oklch(var(--lch-red-lightest))` |
| `bg-red-600` | `background-color` | `oklch(var(--lch-red-dark))` |
| `bg-blue-600` | `background-color` | `oklch(var(--lch-blue-dark))` |
| `text-red-500` | `color` | `oklch(var(--lch-red-medium))` |
| `text-gray-900` | `color` | `var(--color-ink)` |
| `border` | `border` | `1px solid var(--color-ink-light)` |
| `rounded-lg` | `border-radius` | `0.5rem` |
| `rounded-full` | `border-radius` | `9999px` |
| `items-end` | `align-items` | `end` |
| `items-center` | `align-items` | `center` |
| `justify-center` | `justify-content` | `center` |
| `flex flex-col` | `display: flex; flex-direction` | `column` |

## Architecture Patterns

### Recommended BEM Structure

```
.documento-form                       /* Block: form container */
  .documento-form__errors             /* Element: validation errors */
  .documento-form__section            /* Element: major form section */
    --header                          /* Modifier: causale/numero/data section */
    --clientable                      /* Modifier: customer selection section */
    --righe                           /* Modifier: line items section */
  .documento-form__fieldset           /* Element: single field wrapper */
    --causale                         /* Modifier: causale combobox (col-span-4) */
    --numero                          /* Modifier: numero field (col-span-2) */
    --data                            /* Modifier: data field (col-span-2) */
    --full                            /* Modifier: full-width field */
  .documento-form__riga               /* Element: single riga row */
  .documento-form__riga-handle        /* Element: drag handle */
  .documento-form__riga-libro         /* Element: libro combobox wrapper */
  .documento-form__riga-field         /* Element: numeric field */
    --quantita
    --prezzo
    --sconto
  .documento-form__riga-delete        /* Element: delete button */
  .documento-form__actions            /* Element: form actions (submit, add riga) */
  .documento-form__submit             /* Element: submit button */
```

### Pattern 1: Section-Based Grid Layout

**What:** Each form section uses CSS Grid with responsive columns.
**When to use:** For the header and clientable sections that contain multiple fields.
**Example:**

```css
/* Source: Mapped from _form.html.erb section styling */
.documento-form__section {
  background-color: var(--color-ink-lighter);
  border: 1px solid var(--color-ink-light);
  border-radius: 0.5rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(4, 1fr);
  margin-block: 1rem;
  padding: 1.25rem 1.5rem;

  @media (min-width: 640px) {
    grid-template-columns: repeat(8, 1fr);
  }
}

.documento-form__section--clientable {
  display: flex;
  flex-direction: column;
  grid-template-columns: unset;
}

.documento-form__section--righe {
  background-color: transparent;
  border: none;
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 0;
}
```

### Pattern 2: Riga Row with Responsive Grid

**What:** Each documento_riga uses grid for field alignment.
**When to use:** For the sortable line item rows.
**Example:**

```css
/* Source: Mapped from _documento_riga.html.erb */
.documento-form__riga {
  align-items: end;
  background-color: var(--color-canvas);
  border: 1px solid var(--color-ink-light);
  border-radius: 0.5rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(4, 1fr);
  margin-block-end: 0.5rem;
  padding: 0.625rem 1rem;

  @media (min-width: 640px) {
    grid-template-columns: repeat(8, 1fr);
  }
}
```

### Pattern 3: Fieldset Column Spans

**What:** Fieldsets use modifiers for grid column placement.
**When to use:** For positioning form fields within the grid.
**Example:**

```css
/* Source: Mapped from _form.html.erb fieldset positioning */
.documento-form__fieldset {
  display: flex;
  flex-direction: column;
  margin-block: 1.25rem;
}

.documento-form__fieldset--causale {
  grid-column: span 4;
}

.documento-form__fieldset--numero,
.documento-form__fieldset--data {
  grid-column: span 2;
}

.documento-form__fieldset--full {
  grid-column: 1 / -1;
}
```

### Pattern 4: Preserve Existing Component Systems

**What:** Keep Tailwind classes inside components that have their own styling system.
**When to use:** For inline_edit, tax_button, and combobox components.
**Example:**

From prior decisions:
- `inline_edit` partial uses `group-[.inline-edit]:` for visibility toggling
- `tax_button` component has its own color system via component props
- Combobox components (`cb-tax`, `cb-tax-fancy`) have dedicated styling

These should NOT be migrated to BEM in this phase.

### Anti-Patterns to Avoid

- **Migrating combobox styling:** The `cb-tax` and `cb-tax-fancy` classes are part of the Hotwire Combobox system - leave unchanged.
- **Changing inline_edit behavior:** The `group-[.inline-edit]:` pattern relies on specific Tailwind class structure.
- **Hardcoding form colors:** Use `--color-*` and `--lch-*` tokens for all colors.
- **Breaking Stimulus controller data attributes:** Preserve all `data-*` attributes exactly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Section backgrounds | Custom gray values | `var(--color-ink-lighter)` | Design token consistency |
| Error styling | Custom red values | `--lch-red-*` tokens | Theme-aware |
| Button styling | New button component | Existing submit button pattern | Consistency |
| Sortable behavior | Custom drag/drop | Existing sortable Stimulus controller | Already works |
| Combobox styling | New combobox CSS | Existing `cb-tax`, `cb-tax-fancy` | Hotwire Combobox integration |
| Input styling | New input component | Existing `.field` class + Tailwind inputs | Leave inputs as-is |

## Common Pitfalls

### Pitfall 1: Breaking Sortable Controller

**What goes wrong:** Drag-and-drop stops working after CSS migration.
**Why it happens:** Sortable controller relies on specific class names or DOM structure.
**How to avoid:** Keep the `handle` class for drag handle, preserve `data-sortable-*` attributes.
**Warning signs:** Cannot reorder righe, no drag cursor.

### Pitfall 2: Breaking Combobox Autocomplete

**What goes wrong:** Combobox dropdown doesn't appear or position incorrectly.
**Why it happens:** Hotwire Combobox has CSS dependencies via `cb-tax` classes.
**How to avoid:** Keep `cb-tax` and `cb-tax-fancy` classes, don't wrap in new containers.
**Warning signs:** Autocomplete list doesn't appear, dropdown misaligned.

### Pitfall 3: Inline Fields Visibility Toggle

**What goes wrong:** Status/payment fields don't show save/cancel buttons in edit mode.
**Why it happens:** `group-[.inline-edit]:` selector depends on `.inline-edit` class on parent.
**How to avoid:** Keep the Tailwind group-based visibility pattern unchanged.
**Warning signs:** Save/cancel buttons always hidden or always visible.

### Pitfall 4: Mobile Grid Column Overflow

**What goes wrong:** Fields wrap incorrectly or overflow on mobile.
**Why it happens:** `col-start-2` on mobile creates gap before prezzo field.
**How to avoid:** Use responsive column start: `col-start-2 sm:col-start-auto`.
**Warning signs:** Numeric fields misaligned on mobile view.

### Pitfall 5: Form Submit Button Disabled State

**What goes wrong:** Submit button doesn't show disabled state during submission.
**Why it happens:** Original uses `cursor-not-allowed opacity-50` classes conditionally.
**How to avoid:** Include both enabled and disabled states in BEM.
**Warning signs:** No visual feedback during form submission.

### Pitfall 6: Nested Form Fields_for Structure

**What goes wrong:** Riga nested attributes don't save correctly.
**Why it happens:** `fields_for` generates specific name attributes that must be preserved.
**How to avoid:** Only change CSS classes, never modify `fields_for` structure or hidden fields.
**Warning signs:** Righe not saved, validation errors on hidden ID fields.

## Code Examples

### Form Section Styles

```css
/* Source: Mapped from _form.html.erb sections */
.documento-form__section {
  background-color: var(--color-ink-lighter);
  border: 1px solid var(--color-ink-light);
  border-radius: 0.5rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(4, 1fr);
  margin-block: 1rem;
  padding: 1.25rem 1.5rem;

  @media (min-width: 640px) {
    grid-template-columns: repeat(8, 1fr);
  }
}

.documento-form__section--header {
  /* Uses default grid styling */
}

.documento-form__section--clientable {
  display: flex;
  flex-direction: column;
  margin-block-end: 1rem;
}

.documento-form__section--righe {
  background-color: transparent;
  border: none;
  display: block;
  margin-block: 0;
  padding: 0;
}
```

### Fieldset Styles

```css
/* Source: Mapped from _form.html.erb fieldsets */
.documento-form__fieldset {
  display: flex;
  flex-direction: column;
  margin-block: 1.25rem;
}

.documento-form__fieldset--causale {
  grid-column: span 4;
}

.documento-form__fieldset--numero {
  grid-column: span 2;
}

.documento-form__fieldset--data {
  grid-column: span 2;
}

.documento-form__fieldset--small {
  margin-block: 0.5rem;
}
```

### Error Display Styles

```css
/* Source: Mapped from _form.html.erb error display */
.documento-form__errors {
  background-color: oklch(var(--lch-red-lightest));
  border-radius: 0.5rem;
  color: oklch(var(--lch-red-medium));
  font-weight: 500;
  margin-block-start: 0.75rem;
  padding: 0.5rem 0.75rem;
}
```

### Riga Row Styles

```css
/* Source: Mapped from _documento_riga.html.erb */
.documento-form__riga {
  align-items: end;
  background-color: var(--color-canvas);
  border: 1px solid var(--color-ink-light);
  border-radius: 0.5rem;
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(4, 1fr);
  margin-block-end: 0.5rem;
  padding: 0.625rem 1rem;

  @media (min-width: 640px) {
    grid-template-columns: repeat(8, 1fr);
  }
}

.documento-form__riga-handle {
  cursor: move;
  flex-shrink: 0;
  padding-inline-end: 1rem;
}

.documento-form__riga-libro {
  align-items: center;
  display: flex;
  grid-column: span 4;
}

.documento-form__riga-field {
  align-items: center;
  display: flex;
  flex-direction: column;
  grid-column: span 1;
  justify-content: space-between;
}

.documento-form__riga-field--prezzo {
  @media (max-width: 639px) {
    grid-column-start: 2;
  }
}

.documento-form__riga-delete {
  align-items: center;
  background-color: oklch(var(--lch-red-dark));
  block-size: 1.75rem;
  border-radius: 9999px;
  color: var(--color-ink-inverted);
  display: flex;
  inline-size: 1.75rem;
  justify-content: center;
  margin-block-end: 0.375rem;
  margin-inline: 0.5rem;
  transition: background-color 150ms ease;

  &:hover {
    background-color: oklch(var(--lch-red-medium));
  }

  &:focus-visible {
    outline: 2px solid oklch(var(--lch-red-dark));
    outline-offset: 2px;
  }
}
```

### Form Actions Styles

```css
/* Source: Mapped from _form.html.erb actions */
.documento-form__actions {
  display: inline;
  padding-inline: 1rem;
}

.documento-form__submit {
  background-color: oklch(var(--lch-blue-dark));
  border-radius: 0.5rem;
  color: var(--color-ink-inverted);
  cursor: pointer;
  display: inline-block;
  font-weight: 500;
  padding: 0.75rem 1.25rem;
  transition: background-color 150ms ease;

  &:hover {
    background-color: oklch(var(--lch-blue-medium));
  }

  &:disabled {
    background-color: var(--color-ink-light);
    cursor: not-allowed;
    opacity: 0.5;
  }
}
```

### Numeric Input Styling (Reference Only)

The numeric inputs use extensive Tailwind for spinner removal and ring styling. Per prior decisions, these should remain Tailwind:

```erb
<%# Keep this Tailwind pattern unchanged %>
class: [
  "text-right [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none": true,
  "w-full rounded-md border-0 py-2 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-gray-600": true
]
```

## Scope Boundaries

### In Scope (Phase 8)

1. `.documento-form` block and its direct elements
2. Form section containers (`__section--header`, `__section--clientable`, `__section--righe`)
3. Fieldset positioning (`__fieldset` with column span modifiers)
4. Riga row container (`__riga`) and structural elements
5. Error display styling (`__errors`)
6. Submit button styling (`__submit`)

### Explicitly Out of Scope

1. **Combobox internals** - `cb-tax`, `cb-tax-fancy` classes stay
2. **Input field styling** - Keep existing `.field` class and Tailwind inputs
3. **inline_fields partial** - Preserve `group-[.inline-edit]:` patterns
4. **tax_button component** - Has its own color/styling system
5. **TaxSelectClientableComponent** - Internal styling unchanged
6. **Label helpers** - `label_for` helper output unchanged

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Tailwind utilities per section | BEM block with section modifiers | Maintainable, consistent |
| Inline grid classes | CSS Grid in stylesheet | Responsive breakpoints in one place |
| Multiple margin/padding utilities | Unified spacing tokens | Consistent vertical rhythm |

**Key insight:** The form has clear separation between container/layout concerns (migrate to BEM) and interactive component concerns (keep existing systems). Focus BEM migration on the structural elements only.

## Open Questions

1. **Input validation styling**
   - What we know: Rails adds error classes to invalid fields
   - What's unclear: Should validation error styling be part of `.documento-form` or global?
   - Recommendation: Keep validation styling global, don't duplicate in documento-form

2. **Add riga button positioning**
   - What we know: Uses TaxButtonComponent with `url_for` for turbo_stream
   - What's unclear: Should the button wrapper get BEM styling?
   - Recommendation: Add `.documento-form__add-riga` wrapper class but keep button component unchanged

3. **Inline edit toggle behavior**
   - What we know: Uses `shared/inline_fields` partial with turbo_frame
   - What's unclear: Should status/payment fields in header section get BEM classes?
   - Recommendation: Wrap in `.documento-form__status-fields` but preserve internal Tailwind

## Sources

### Primary (HIGH confidence)
- `/home/paolotax/rails_2023/prova/app/views/documenti/_form.html.erb` - Main form partial (100 lines)
- `/home/paolotax/rails_2023/prova/app/views/documento_righe/_documento_riga.html.erb` - Riga partial (87 lines)
- `/home/paolotax/rails_2023/prova/app/views/shared/_inline_fields.html.erb` - Inline fields partial (20 lines)
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/documenti.css` - Phase 4-7 infrastructure (743 lines)
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/_global.css` - Design tokens
- `/home/paolotax/rails_2023/prova/app/assets/stylesheets/inputs.css` - Input styling patterns

### Secondary (HIGH confidence)
- `/home/paolotax/rails_2023/prova/.planning/phases/06-document-card/06-RESEARCH.md` - Causale modifier patterns
- `/home/paolotax/rails_2023/prova/.planning/phases/07-detail-view/07-RESEARCH.md` - Table/grid patterns
- `/home/paolotax/rails_2023/prova/app/components/tax_select_clientable_component.html.erb` - Clientable component
- `/home/paolotax/rails_2023/prova/app/components/tax_button_component.html.erb` - Button component

### Tertiary (MEDIUM confidence)
- `/home/paolotax/rails_2023/prova/app/views/documenti/new.html.erb` - Form wrapper context
- `/home/paolotax/rails_2023/prova/app/views/documenti/edit.html.erb` - Form wrapper context

## Metadata

**Confidence breakdown:**
- Form structure analysis: HIGH - Direct code inspection
- Tailwind-to-CSS mapping: HIGH - Straightforward utility translation
- Section layout patterns: HIGH - Clear grid structure
- Component boundary decisions: HIGH - Explicit prior decisions
- Input styling scope: MEDIUM - Judgment call on preservation

**Research date:** 2026-01-18
**Valid until:** 30 days (stable domain, internal codebase patterns)
