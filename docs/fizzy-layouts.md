# Fizzy Layout System

## Architettura base

Body usa CSS Grid a 4 righe:

```css
body {
  display: grid;
  grid-template-rows: auto 1fr auto 9em; /* header | main | footer placeholder | footer */
}
```

`#main` ha padding responsive:
```css
#main {
  inline-size: 100dvw;
  padding-inline: calc(var(--main-padding) + env(safe-area-inset-left));
}
```

CSS Layers per cascade control:
```css
@layer reset, base, components, modules, utilities, native, platform;
```

---

## 1. `.settings` — Grid 2 colonne uguali

**File:** `settings.css`

```css
.settings {
  --settings-spacer: var(--block-space);
  display: grid;
  gap: calc(var(--settings-spacer) * 2);
  max-inline-size: min(100ch, 100%);

  @media (min-width: 960px) {
    grid-template-columns: repeat(2, 1fr);
  }
}

.settings__panel {
  --panel-size: 100%;
  display: flex;
  flex-direction: column;
  gap: calc(var(--settings-spacer) / 2);
  min-inline-size: 0;

  @media (min-width: 960px) {
    --panel-padding: calc(var(--settings-spacer) * 1.5) calc(var(--settings-spacer) * 2);
  }
}
```

**Comportamento:**
- Mobile: colonna singola, pannelli impilati
- Desktop (>=960px): 2 colonne uguali, max 100ch
- Ogni panel e' flex column con gap tra sotto-pannelli

**Uso tipico:**
```erb
<section class="settings margin-block-start-half">
  <div class="settings__panel">
    <article class="panel shadow"><!-- info --></article>
    <article class="panel shadow"><!-- altro --></article>
  </div>
  <div class="settings__panel">
    <article class="panel shadow"><!-- contenuto --></article>
  </div>
</section>
```

**In Prova:** scuole/container, classi/show

---

## 2. `.card-perma` — Grid 3 aree con card centrale

**File:** `card-perma.css`

```css
.card-perma {
  display: grid;
  grid-template-areas:
    "notch-top    notch-top    notch-top"
    "actions-left card         actions-right"
    "notch-bottom notch-bottom notch-bottom"
    "closure-message closure-message closure-message";
  grid-template-columns: 48px minmax(0, 1120px) 48px;
  margin-inline: auto;

  @media (max-width: 799px) {
    grid-template-areas:
      "notch-top     notch-top    notch-top"
      "card          card         card"
      "actions-left  notch-bottom actions-right"
      "closure-message closure-message closure-message";
    grid-template-columns: 1fr auto 1fr;
  }
}
```

**Comportamento:**
- Desktop: card al centro, azioni a sinistra/destra (48px ciascuna)
- Mobile (<=799px): card full-width, azioni sotto la card
- Animazione di ingresso: `card-perma-entrance 300ms ease-out`

**Aree child:**
```css
.card-perma__bg          { grid-area: card; }
.card-perma__actions--left  { grid-area: actions-left; }
.card-perma__actions--right { grid-area: actions-right; }
.card-perma__notch--top     { grid-area: notch-top; }
.card-perma__notch--bottom  { grid-area: notch-bottom; }
```

**In Prova:** show di appunti e documenti

---

## 3. `.comments` — Colonna centrata per thread

**File:** `comments.css`

```css
.comments {
  --comment-max: 70ch;
  display: flex;
  flex-direction: column;
  padding-inline: var(--inline-space);
  place-items: center;
  text-align: center;

  @media (min-width: 160ch) {
    padding-inline: var(--tray-size);
  }
}

.comment {
  &:where(.comments &) {
    max-inline-size: var(--comment-max);
    margin-inline: auto;
  }
}
```

**Comportamento:**
- Flex column centrata, max 70ch per comment
- Ultra-wide (>=160ch): padding extra ai lati
- Usata come sidebar destra nel layout clienti/show

**In Prova:** clienti/show, libri/show (dentro `full-width card-grid`)

---

## 4. `.card-columns` — Kanban 3 colonne

**File:** `card-columns.css`

```css
.card-columns {
  display: grid;
  gap: var(--column-gap);
  grid-template-columns: 1fr auto 1fr;
  max-inline-size: var(--main-width);
  overflow-x: auto;

  &:has(.is-expanded) {
    grid-template-columns: auto var(--column-width-expanded) auto;
  }
}
```

**Mobile (<=639px):**
- Scroll orizzontale con snap
- Colonne collassate = barre verticali sottili (40px)
- Colonna espansa = 100vw

**Cards grid (filtro attivo):**
```css
.cards--grid {
  --card-grid-columns: 1;
  container-type: inline-size;

  @media (min-width: 640px) { --card-grid-columns: 2; }
  @media (min-width: 960px) { --card-grid-columns: 3; }

  .card {
    font-size: clamp(0.6rem, 0.85cqi, 100px);
    inline-size: calc((100% - var(--cards-gap) * (var(--card-grid-columns) - 1)) / var(--card-grid-columns));
  }
}
```

**In Prova:** dashboard, appunti/index, documenti/index

---

## 5. `.profile-layout` — 2 pannelli flex

**File:** `profile-layout.css`

```css
.profile-layout {
  display: flex;
  gap: var(--inline-space);

  @media (min-width: 800px) {
    flex-direction: row;
    justify-content: center;
  }
  @media (max-width: 799px) {
    flex-direction: column;
    align-items: center;
  }
}
```

**Differenza da .settings:**
- Flexbox (non grid) — pannelli hanno dimensione propria
- Breakpoint 800px (non 960px)
- Pannelli centrati, non full-width

**Uso:** `users/show` con `--panel-size: 45ch` inline

---

## 6. `.panel` — Componente contenitore

**File:** `panels.css`

```css
.panel {
  background-color: var(--panel-bg, var(--color-canvas));
  border: var(--panel-border-size, 1px) solid var(--panel-border-color, var(--color-ink-lighter));
  border-radius: var(--panel-border-radius, 1em);
  inline-size: var(--panel-size, 60ch);
  max-inline-size: 100%;
  padding: var(--panel-padding, var(--block-space));
}
```

Customizzabile via CSS custom properties inline:
```erb
<div class="panel" style="--panel-size: 45ch;">
```

---

## Variabili di spacing

```css
--inline-space: 1ch;
--inline-space-half: calc(var(--inline-space) / 2);
--inline-space-double: calc(var(--inline-space) * 2);
--block-space: 1rem;
--block-space-half: calc(var(--block-space) / 2);
--block-space-double: calc(var(--block-space) * 2);
--main-padding: clamp(var(--inline-space), 3vw, calc(var(--inline-space) * 3));
--main-width: 1400px;
```

---

## Breakpoints

| Breakpoint | Contesto |
|------------|----------|
| 480px | Mobile small (card-perma notch buttons) |
| 640px | Mobile/tablet (card-columns, cards-grid 2 col) |
| 800px | Tablet/desktop (profile-layout row) |
| 960px | Desktop (settings 2 col, cards-grid 3 col) |
| 160ch | Ultra-wide (comments extra padding) |

---

## Riepilogo layout per tipo pagina

| Tipo pagina | Classe layout | Colonne | Note |
|-------------|--------------|---------|------|
| Settings/Config | `.settings` | 1 -> 2 (960px) | Grid, colonne uguali |
| Show entry | `.card-perma` | actions\|card\|actions | Grid areas, card centrata |
| Show risorsa | `.comments` in `full-width` | container + sidebar | Flow + flex column 70ch |
| Kanban/Index | `.card-columns` | 3 col snap | Grid con scroll mobile |
| Profilo | `.profile-layout` | 1 -> 2 (800px) | Flex, pannelli centrati |
| Cards filtrate | `.cards--grid` | 1 -> 2 -> 3 | Container queries |

---

## Pattern chiave

1. **CSS custom properties con fallback** — `var(--panel-size, 60ch)`
2. **Logical properties** — `inline-size`, `block-size`, `margin-inline`, `padding-block`
3. **Mobile-first** — base = mobile, `@media (min-width)` per desktop
4. **Container queries** — `.cards--grid` usa `cqi` units
5. **CSS layers** — `@layer components { }` per cascade prevedibile
6. **Grid per layout pagina, Flexbox per componenti interni**
