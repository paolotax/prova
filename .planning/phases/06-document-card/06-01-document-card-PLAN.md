---
phase: 06-document-card
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/assets/stylesheets/documenti.css
  - app/helpers/documenti_helper.rb
  - app/views/documenti/_documento.html.erb
  - app/views/documenti/_documento_card.html.erb
autonomous: true
user_setup: []

must_haves:
  truths:
    - "User can see documento cards with distinct header, body, and footer sections"
    - "User sees correct causale-based color theming (blue for ordine/entrata, green for vendita/entrata, etc.)"
    - "Cards display responsively (6 columns on mobile, 8 columns on desktop)"
    - "Status badges from Phase 5 render correctly inside card footer"
    - "Selection highlight (current documento) works correctly"
  artifacts:
    - path: "app/assets/stylesheets/documenti.css"
      provides: ".documento BEM block with __header, __body, __footer elements and causale modifier classes"
      contains: ".documento__header"
    - path: "app/helpers/documenti_helper.rb"
      provides: "documento_causale_modifier helper returning BEM modifier string"
      contains: "documento_causale_modifier"
    - path: "app/views/documenti/_documento.html.erb"
      provides: "Main card partial using .documento BEM classes"
      contains: "documento__header"
    - path: "app/views/documenti/_documento_card.html.erb"
      provides: "Compact card variant using .documento--compact modifier"
      contains: "documento--compact"
  key_links:
    - from: "app/views/documenti/_documento.html.erb"
      to: "app/helpers/documenti_helper.rb"
      via: "documento_causale_modifier helper call"
      pattern: "documento_causale_modifier\\(documento\\)"
    - from: "app/assets/stylesheets/documenti.css"
      to: "app/assets/stylesheets/_global.css"
      via: "--lch-* color tokens"
      pattern: "var\\(--lch-"
---

<objective>
Migrate the documento card components from Tailwind utilities to BEM CSS.

Purpose: Complete the primary card component migration (CARD-01 through CARD-05), enabling consistent styling and theming for documento list views.

Output: BEM-styled `.documento` block with causale-based color variations, responsive grid footer, and both main and compact card variants.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/phases/06-document-card/06-RESEARCH.md
@.planning/phases/04-foundation/04-01-SUMMARY.md
@.planning/phases/05-status-badges/05-01-SUMMARY.md
@app/assets/stylesheets/documenti.css
@app/assets/stylesheets/cards.css
@app/assets/stylesheets/_global.css
@app/views/documenti/_documento.html.erb
@app/views/documenti/_documento_card.html.erb
@app/helpers/documenti_helper.rb
@app/helpers/causali_helper.rb
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add documento card CSS and helper method</name>
  <files>
    app/assets/stylesheets/documenti.css
    app/helpers/documenti_helper.rb
  </files>
  <action>
Add the `.documento` BEM block CSS to documenti.css in the "Document Card - Phase 6" section.

**In documenti.css, add after the Phase 5 section:**

1. `.documento` base block with CSS custom properties for causale theming:
   - `--doc-causale-bg`, `--doc-causale-text`, `--doc-causale-border` (default to neutral gray)
   - Add `position: relative` for z-index stacking

2. Causale modifier classes (6 combinations from causali_helper.rb):
   - `.documento--ordine-entrata` using `--lch-blue-*` tokens
   - `.documento--ordine-uscita` using `--lch-violet-*` tokens
   - `.documento--vendita-entrata` using `--lch-green-*` tokens
   - `.documento--vendita-uscita` using `--lch-red-*` tokens
   - `.documento--carico-entrata` using `--lch-yellow-*` tokens
   - `.documento--carico-uscita` using `--lch-uncolor-*` tokens

3. `.documento--selected` modifier for current documento highlight (indigo-500 background, white text)

4. `.documento__header` element:
   - Flex layout with `justify-content: space-between`, `align-items: center`
   - Background from `var(--doc-causale-bg)`
   - Border and border-radius (rounded top corners only)
   - Padding: `0.5rem 1rem`

5. `.documento__body` element:
   - Hidden by default (`.hidden` class from Stimulus controller handles visibility)
   - List styling reset for righe

6. `.documento__footer` element:
   - CSS Grid with 6 columns on mobile, 8 columns on desktop (640px breakpoint)
   - Background from `var(--doc-causale-bg)`
   - Border (no top border), padding `1rem`
   - `&:last-child` with bottom border-radius and box-shadow

7. Footer child elements:
   - `.documento__badges` - `grid-column: 1 / -1` (full width)
   - `.documento__avatars` - `grid-column: span 3` (mobile), `span 2` (desktop)
   - `.documento__copies` - `grid-column: span 1`, right-aligned, bold
   - `.documento__amount` - `grid-column: span 2`, right-aligned, bold

8. Responsive adjustments at 640px:
   - Footer columns change from 6 to 8
   - `.documento__copies` starts at column 5
   - `.documento__amount` starts at column 7

9. `.documento--compact` modifier for the alternative card variant:
   - Single section (no header/body/footer split)
   - Full border-radius, box-shadow
   - Link-style content

**In documenti_helper.rb, add helper method:**

```ruby
def documento_causale_modifier(documento)
  return "" unless documento&.causale

  tipo = documento.causale.tipo_movimento
  mov = documento.causale.movimento

  "documento--#{tipo}-#{mov}"
end
```

This replaces the Tailwind class return from `documento_header_bg_classes`.
  </action>
  <verify>
Run `docker exec -it prova-app-1 bin/rails runner "puts DocumentiHelper.instance_methods(false)"` to confirm `documento_causale_modifier` is defined.
Verify CSS syntax: `cat app/assets/stylesheets/documenti.css | head -200` should show new classes without errors.
  </verify>
  <done>
- documenti.css contains `.documento` block with `__header`, `__body`, `__footer` elements
- 6 causale modifier classes defined using OKLCH color tokens
- Helper method `documento_causale_modifier` returns BEM modifier string
- Responsive grid defined with 640px breakpoint
  </done>
</task>

<task type="auto">
  <name>Task 2: Refactor _documento.html.erb to use BEM classes</name>
  <files>
    app/views/documenti/_documento.html.erb
  </files>
  <action>
Replace Tailwind utility classes with BEM semantic classes in _documento.html.erb.

**Structure transformation:**

1. **Root div** (line 1):
   - Replace `class="w-full item"` with `class: class_names("documento", documento_causale_modifier(documento), "documento--selected": @documento == documento)`
   - Keep `id` and `data-controller="tax-reveal"`

2. **Header** (line 3):
   - Replace `class: ["px-4 py-2 flex items-center justify-between border rounded-tl-lg rounded-tr-lg", documento_header_bg_classes(documento)]`
   - With `class: "documento__header"`

3. **Header content div** (line 5):
   - Replace `class: "block sm:flex gap-4 items-start"` with `class: "documento__header-content"`
   - This is a layout container, add `.documento__header-content` to CSS if needed

4. **Checkbox container** (line 7):
   - Replace `class: "flex flex-shrink-0 items-center justify-start gap-2"` with `class: "documento__checkbox"`
   - KEEP the checkbox input's existing Tailwind classes (per research: checkbox styling out of scope)

5. **Cliente section** (line 21):
   - Replace the `tag.div class: ["text-sm text-gray-500", "text-white": @documento == documento]`
   - With `class: "documento__cliente"`
   - The selection state white text is handled by `.documento--selected` cascading

6. **Actions wrapper** (line 38):
   - Replace `class: "flex flex-col sm:flex-row gap-2 wrap"` with `class: "documento__actions"`
   - KEEP tax_button component calls unchanged (per research: button components out of scope)

7. **Body ul** (line 76):
   - Replace `class: "hidden"` with `class: "documento__body hidden"`
   - The `hidden` class is toggled by Stimulus, keep it

8. **Footer** (line 84):
   - Replace `class: ["p-4 border border-t-0 border-gray-300 mb-4 last:rounded-b-lg last:shadow-md grid grid-cols-6 sm:grid-cols-8", documento_footer_bg_classes(documento)]`
   - With `class: "documento__footer"`

9. **Footer children:**
   - Badges container (line 86): Replace `class: "col-span-6 sm:col-span-8 flex gap-2 sm:gap-4 mb-2"` with `class: "documento__badges"`
   - Avatars container (line 90): Replace `class: "col-span-3 sm:col-span-2 flex gap-2 sm:gap-4"` with `class: "documento__avatars"`
   - Copies div (line 94): Replace `class: "col-start-4 sm:col-start-5 col-span-1 px-3 text-sm font-bold text-right leading-6 text-gray-900"` with `class: "documento__copies"`
   - Amount div (line 98): Replace `class: "col-start-5 sm:col-start-7 col-span-2 pl-3 text-sm font-bold text-right leading-6 text-gray-900"` with `class: "documento__amount"`

**Elements to leave unchanged:**
- Checkbox input styling (line 8-12)
- Link styling (line 15)
- tax_button component calls (lines 40-71)
- Nested partial renders (clientables, righe, status_badges, StackedLibriComponent)
- All data- attributes and Stimulus controller bindings
  </action>
  <verify>
Run `docker exec -it prova-app-1 bin/rails test test/controllers/documenti_controller_test.rb` to ensure views render.
Check for Tailwind classes that should be removed: `grep -E "(px-|py-|flex|grid-cols|col-span|col-start|text-sm|text-gray|bg-)" app/views/documenti/_documento.html.erb` should return minimal results (only checkbox and link styling kept).
  </verify>
  <done>
- _documento.html.erb uses BEM classes: `.documento`, `.documento__header`, `.documento__body`, `.documento__footer`
- Causale modifier applied via `documento_causale_modifier(documento)` helper
- Selection state uses `.documento--selected` modifier
- Footer uses semantic `.documento__badges`, `.documento__avatars`, `.documento__copies`, `.documento__amount` classes
- Checkbox and tax_button components retain their existing styling
  </done>
</task>

<task type="auto">
  <name>Task 3: Refactor _documento_card.html.erb to use compact variant</name>
  <files>
    app/views/documenti/_documento_card.html.erb
  </files>
  <action>
Convert the simpler _documento_card.html.erb to use `.documento--compact` variant.

**Structure transformation:**

1. **Root div** (line 1):
   - Replace `class: ["w-full border rounded-lg shadow-lg p-4 mb-4", "bg-white": @documento != documento, "bg-indigo-500 text-white": @documento == documento]`
   - With `class: class_names("documento documento--compact", documento_causale_modifier(documento), "documento--selected": @documento == documento)`

2. **Link wrapper** (line 4):
   - Add `class: "documento__link"` to the link_to

3. **Content paragraphs:**
   - The causale/numero header: Add `class: "documento__title"`
   - Cliente info (line 11): Replace `class: ["text-right text-sm text-gray-500", "text-white": @documento == documento]` with `class: "documento__cliente"`
   - Counts line (line 17): Replace `class: ["text-right text-sm font-semibold text-gray-500", "text-white": @documento == documento]` with `class: "documento__meta"`
   - Amount line (line 24): Replace similar classes with `class: "documento__meta"`
   - Status line (line 29): Replace similar classes with `class: "documento__meta"`

**Update CSS for compact variant:**

Add to documenti.css in the Document Card section:

```css
.documento--compact {
  background-color: var(--doc-causale-bg, var(--color-canvas));
  border: var(--doc-border);
  border-radius: var(--doc-border-radius);
  box-shadow: var(--shadow);
  margin-block-end: 1rem;
  padding: 1rem;
}

.documento--compact .documento__link {
  color: inherit;
  text-decoration: none;
}

.documento--compact .documento__title {
  font-weight: 600;
}

.documento--compact .documento__cliente,
.documento--compact .documento__meta {
  color: var(--doc-text-muted);
  font-size: var(--text-small);
  text-align: end;
}

.documento--compact .documento__meta {
  font-weight: 600;
}

.documento--compact.documento--selected {
  background-color: oklch(var(--lch-violet-medium));
  color: var(--color-ink-inverted);
}

.documento--compact.documento--selected .documento__cliente,
.documento--compact.documento--selected .documento__meta {
  color: inherit;
}
```

This ensures the compact variant maintains visual parity with the current Tailwind implementation while using semantic classes.
  </action>
  <verify>
Check for remaining Tailwind classes: `grep -E "(bg-white|bg-indigo|text-gray|text-white|rounded-lg|shadow-lg)" app/views/documenti/_documento_card.html.erb` should return nothing.
Verify CSS syntax by checking file loads: `docker exec -it prova-app-1 bin/rails runner "Rails.application.config.assets.compile"` should not error.
  </verify>
  <done>
- _documento_card.html.erb uses `.documento--compact` modifier
- All Tailwind utility classes removed from partial
- Causale theming applied via same helper as main card
- Selection state uses same `.documento--selected` modifier
- Visual appearance matches previous implementation
  </done>
</task>

</tasks>

<verification>
After all tasks complete:

1. **Visual verification:** Visit `/documenti` in browser
   - Cards should display with correct causale colors
   - Header, footer sections should be visually distinct
   - Mobile view (< 640px): 6-column footer grid
   - Desktop view (> 640px): 8-column footer grid

2. **Selection state:** Click a documento
   - Selected card should highlight with indigo background and white text

3. **Status badges:** Check footer section
   - Badges from Phase 5 should render correctly inside `.documento__badges`

4. **Compact variant:** If `_documento_card.html.erb` is used anywhere
   - Should render with border-radius, shadow, proper theming

5. **Tailwind removal check:**
   ```bash
   grep -c "bg-\|px-\|py-\|flex\|grid-cols\|col-span\|text-sm\|text-gray" app/views/documenti/_documento.html.erb
   grep -c "bg-\|px-\|py-\|flex\|grid-cols\|col-span\|text-sm\|text-gray" app/views/documenti/_documento_card.html.erb
   ```
   Results should be minimal (only checkbox and link Tailwind preserved).
</verification>

<success_criteria>
1. Documento cards display with header, body, and footer sections clearly visible
2. Cards respond correctly at mobile (<640px) and desktop (>640px) breakpoints
3. Different causale types show appropriate color accents (6 combinations)
4. `_documento.html.erb` and `_documento_card.html.erb` contain no Tailwind utility classes (except checkbox/link styling)
5. Card hover and selection states work correctly
6. Status badges (Phase 5) render correctly inside card footer
</success_criteria>

<output>
After completion, create `.planning/phases/06-document-card/06-01-SUMMARY.md`
</output>
