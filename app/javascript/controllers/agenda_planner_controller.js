import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["body", "toggle", "giroFilter"]

  // Planner → Calendar: native drag
  dragStart(event) {
    const el = event.currentTarget
    const tappaId = el.dataset.tappaId
    const name = el.querySelector(".txt-x-small")?.textContent?.trim() || ""
    event.dataTransfer.setData("application/x-tappa-ids", JSON.stringify([{ id: tappaId, name }]))
    event.dataTransfer.effectAllowed = "move"
    el.classList.add("dragging")
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("dragging")
  }

  // Calendar → Planner: native drop zone
  dropzoneOver(event) {
    if (event.dataTransfer.types.includes("application/x-tappa-ids")) {
      event.preventDefault()
      this.bodyTarget.classList.add("agenda-planner__body--drop-target")
    }
  }

  dropzoneLeave(event) {
    // Only remove if leaving the body entirely
    if (!this.bodyTarget.contains(event.relatedTarget)) {
      this.bodyTarget.classList.remove("agenda-planner__body--drop-target")
    }
  }

  async dropzoneDrop(event) {
    event.preventDefault()
    this.bodyTarget.classList.remove("agenda-planner__body--drop-target")

    const raw = event.dataTransfer.getData("application/x-tappa-ids")
    if (!raw) return

    const items = JSON.parse(raw)
    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""

    for (const item of items) {
      const tappaId = item.id || item

      // Remove from calendar
      const calendarCard = document.getElementById(`tappa_${tappaId}`)
      if (calendarCard) calendarCard.remove()

      // PATCH with null date
      await patch(`${prefix}/tappe/${tappaId}/sort`, {
        body: JSON.stringify({ data_tappa: null, position: 0 }),
        contentType: "application/json"
      })
    }

    // Reload planner frame
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.reload()
  }

  filterGiro(event) {
    const giroId = event.target.value
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""
    frame.src = giroId
      ? `${prefix}/agenda/planner?giro_id=${giroId}`
      : `${prefix}/agenda/planner`
  }
}
