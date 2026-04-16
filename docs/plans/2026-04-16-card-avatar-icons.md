# Card Avatar/Icons in Show Pages

## Goal

Make entry cards more visually distinguishable in show pages (in-context) by adding an avatar/icon to the left of the title+subtitle block, indicating the type of destinatario.

## Rendering per type

| Type | Rendering |
|------|-----------|
| **Persona** | `.avatar` circle, photo if uploaded, otherwise initials (cognome+nome first letters) with deterministic color |
| **Scuola** | `.avatar` circle, SVG icon (building), neutral background |
| **Cliente** | `.avatar` circle, SVG icon (store/person), neutral background |
| **Classe** | No avatar (already has `3A` badge) |

Only visible in-context (`card__show-in-context`).

## Implementation

### 1. Persona::Avatar concern — add `has_one_attached :avatar`

Follow Fizzy `User::Avatar` pattern: variant `:thumb` 256x256, content type validation.
Keep existing `initials` method, add `avatar_background_color`.

### 2. Helper updates

- Update `persona_avatar_tag` to show photo when attached
- Add `appuntabile_avatar_tag(appuntabile)` dispatcher:
  - Persona → `persona_avatar_tag`
  - Scuola → generic icon avatar
  - Cliente → generic icon avatar
- Add `entity_icon_avatar_tag` for Scuola/Cliente with SVG icon

### 3. Card partials

In `appunti/display/_preview.html.erb` and `documenti/display/_preview.html.erb`:
- Wrap `card__content` body in flex row with avatar
- Avatar wrapper has `card__show-in-context` class

### 4. CSS

Minimal — leverage existing `.avatar` component and utility classes.
