---
name: icon-agent
description: Adds icons for buttons/actions in the Prova app. Use when a view needs an icon that isn't registered yet, or when icon_tag renders nothing because the icon is missing. Triggers: "aggiungi icona", "icona pulsante", "icon_tag non si vede", "manca l'icona".
---

You add icons to the Prova app following its CSS-mask icon system. Icons are rendered
with `icon_tag "name"`, masked from an SVG via a CSS custom property.

## How icons work here

- Helper: `icon_tag(name, class: "icon--small")` → `app/helpers/application_helper.rb`
  emits `<span class="icon icon--<name>" aria-hidden="true">`.
- CSS: `app/assets/stylesheets/icons.css` maps each name to its SVG:
  ```css
  .icon--<name> { --svg: url("<name>.svg"); }
  ```
  The `.icon` base rule uses `mask-image: var(--svg)` + `background-color: currentColor`,
  so the icon takes the **current text color**. The SVG's own `fill`/color is irrelevant —
  only its **shape (alpha)** is used as a mask.
- SVG files live **flat** in `app/assets/images/` (Propshaft serves them; the `url("…")`
  in icons.css is relative to that directory).
- Sizes: add `icon--small` (or other size util) on the element. Default is `1em`.

**If `icon_tag "foo"` renders an empty box, the `.icon--foo` line is missing from icons.css**
(or the SVG file is absent). That's the bug this skill fixes.

## Procedure

Follow these steps in order. Stop as soon as the icon already exists.

### 1. Check if it already exists
```bash
grep "icon--<name>" app/assets/stylesheets/icons.css
```
If present, just use `icon_tag "<name>"` in the view — done.

### 2. Find the SVG source

**First choice — local heroicons** (already vendored, consistent style):
```bash
ls app/assets/svg/icons/heroicons/{mini,micro,outline,solid}/ | grep -i <keyword>
```
- Prefer **`mini`** (20×20, filled) — best match for inline button icons.
- Use `solid` for larger filled icons. **Avoid `outline`** for the mask system:
  outline icons are stroke-only with no fill, so they mask into thin/empty shapes.
- The shape must be **filled** (the mask uses alpha). Filled heroicons mask cleanly.

**Second choice — internet** (only if no good local match):
- Grab from https://heroicons.com (keeps the style consistent) or another permissive
  source (Lucide, Feather). Pick a **filled/solid** variant when possible.
- Ensure it's a clean `<svg>` with a `viewBox` and a filled `<path>`. The fill color
  doesn't matter (masked away), but the shape must be solid, not stroke-only.

### 3. Copy into app/assets/images with a clear name
```bash
cp app/assets/svg/icons/heroicons/mini/<source>.svg app/assets/images/<name>.svg
```
Name it for its **purpose** when generic (e.g. `drag-handle.svg`, not `bars-3.svg`),
or keep the source name when it's already descriptive.

### 4. Register it in icons.css
Add one line near the related icons:
```css
.icon--<name> { --svg: url("<name>.svg"); }
```

### 5. Use it
```erb
<%= icon_tag "<name>", class: "icon--small txt-subtle" %>
```

### 6. Note for the user
Assets are fingerprinted by Propshaft — in dev a **hard refresh** (or
`bin/rails assets:clobber`) may be needed before the new icon shows.

## Worked example (drag handle)

A reorder handle was needed but `bars-3` wasn't registered:
```bash
cp app/assets/svg/icons/heroicons/mini/bars-3.svg app/assets/images/drag-handle.svg
```
```css
/* icons.css */
.icon--drag-handle { --svg: url("drag-handle.svg"); }
```
```erb
<%= icon_tag "drag-handle", class: "icon--small txt-subtle" %>
```

## Gotchas

- **Don't use `icon_tag` with a name that has no `.icon--name` line** — it renders an
  empty masked box, not an error. Always register first.
- **Outline SVGs mask poorly** — choose filled/solid/mini variants.
- Some existing lines have a stray trailing space inside the quotes
  (`url("move.svg ")`). That's pre-existing; write yours **without** the space.
- The full vendored set is under `app/assets/svg/icons/heroicons/` — search there
  before reaching for the internet.
