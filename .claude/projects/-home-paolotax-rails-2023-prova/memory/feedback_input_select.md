---
name: input-select-classes
description: Select elements must always use both "input input--select" classes, never just one
type: feedback
---

Select elements must always have both `input input--select` classes together.

**Why:** `input` provides base styling, `input--select` adds the pill shape and caret. Using only one breaks the appearance.

**How to apply:** When writing `f.select` or `<select>` tags, always use `class: "input input--select"`.
