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

    const tappaIdsJson = e.dataTransfer.getData("application/x-tappa-ids")
    if (!tappaIdsJson) return

    const tappaIds = JSON.parse(tappaIdsJson)
    const targetDate = this.element.dataset.giorno
    if (!targetDate || tappaIds.length === 0) return

    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""

    for (const tappaId of tappaIds) {
      await patch(`${prefix}/tappe/${tappaId}/sort`, {
        body: JSON.stringify({ data_tappa: targetDate, position: 0 }),
        contentType: "application/json"
      })
    }

    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
