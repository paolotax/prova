import { Controller } from "@hotwired/stimulus"

// Enables dragging an entire day (all tappe) from the calendar.
// Attach to .agenda-week__day or .agenda-week__day--weekend.
export default class extends Controller {
  start(event) {
    const tappeContainer = this.element.querySelector(".agenda-week__tappe")
    const tappaEls = tappeContainer ? tappeContainer.querySelectorAll("[data-tappa-id]") : []

    if (tappaEls.length === 0) {
      event.preventDefault()
      return
    }

    const items = Array.from(tappaEls).map(el => ({
      id: el.dataset.tappaId,
      name: el.querySelector(".txt-x-small")?.textContent?.trim() || ""
    }))

    event.dataTransfer.setData("application/x-tappa-ids", JSON.stringify(items))
    event.dataTransfer.effectAllowed = "move"

    // Compact drag ghost: "LUN 3 (5 tappe)"
    const dayName = this.element.querySelector(".agenda-week__day-name")?.textContent?.trim() || ""
    const dayNumber = this.element.querySelector(".agenda-week__day-number")?.textContent?.trim() || ""
    const ghost = document.createElement("div")
    ghost.textContent = `${dayName} ${dayNumber} (${items.length} tappe)`
    ghost.style.cssText = "position:fixed;top:-999px;padding:0.3em 0.6em;background:var(--color-canvas);border:1px solid var(--color-ink-lighter);border-radius:0.3em;font-size:12px;font-weight:700;white-space:nowrap;"
    document.body.appendChild(ghost)
    event.dataTransfer.setDragImage(ghost, 0, 0)
    requestAnimationFrame(() => ghost.remove())

    this.element.classList.add("dragging")
  }

  end() {
    this.element.classList.remove("dragging")
  }
}
