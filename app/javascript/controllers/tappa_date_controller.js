import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

// Handles drag-and-drop from planner panel to day cells.
// Tappa-to-tappa reordering/moving between days is handled by tax-sortable.
export default class extends Controller {
  handleDragOver(e) {
    if (e.dataTransfer.types.includes("application/x-tappa-ids")) {
      e.preventDefault()
      this.element.classList.add("drag-over")
    }
  }

  handleDragLeave() {
    this.element.classList.remove("drag-over")
  }

  async handleDrop(e) {
    e.preventDefault()
    this.element.classList.remove("drag-over")

    const raw = e.dataTransfer.getData("application/x-tappa-ids")
    if (!raw) return

    const items = JSON.parse(raw)
    const targetDate = this.element.dataset.giorno
    if (!targetDate || items.length === 0) return

    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""
    const tappeContainer = this.element.querySelector(".agenda-week__tappe")

    for (const item of items) {
      const tappaId = item.id || item
      const name = item.name || ""

      // Remove from planner
      const plannerCard = document.querySelector(`.agenda-planner__tappa[data-tappa-id="${tappaId}"]`)
      if (plannerCard) {
        // Remove empty direzione if last card
        const direzione = plannerCard.closest(".agenda-planner__direzione")
        plannerCard.remove()
        if (direzione && !direzione.querySelector(".agenda-planner__tappa")) {
          direzione.remove()
        }
      }

      // Insert compact card in day
      if (tappeContainer) {
        const card = document.createElement("div")
        card.className = "tappa-compact"
        card.id = `tappa_${tappaId}`
        card.dataset.tappaId = tappaId
        card.dataset.taxSortableUpdateUrl = `${prefix}/tappe/${tappaId}/sort`
        card.innerHTML = `<div class="tappa-compact__content"><span class="tappa-compact__name">${this.escapeHtml(name)}</span></div>`
        tappeContainer.appendChild(card)
      }

      // PATCH to server
      await patch(`${prefix}/tappe/${tappaId}/sort`, {
        body: JSON.stringify({ data_tappa: targetDate, position: 0 }),
        contentType: "application/json"
      })
    }

    // Update planner badge
    const badge = document.querySelector(".agenda-planner__title .badge")
    if (badge) {
      badge.textContent = document.querySelectorAll(".agenda-planner__tappa").length
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
