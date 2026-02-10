import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    giroId: Number,
    date: String
  }

  // Drag events on the tappa-compact element (source)
  dragStart(e) {
    const tappaEl = e.target.closest("[data-tappa-id]")
    if (!tappaEl) return

    e.dataTransfer.setData("application/tappa-id", tappaEl.dataset.tappaId)
    e.dataTransfer.effectAllowed = "move"
    tappaEl.classList.add("dragging")
  }

  dragEnd(e) {
    const tappaEl = e.target.closest("[data-tappa-id]")
    if (tappaEl) tappaEl.classList.remove("dragging")
  }

  // Drop zone events on the day cell (target)
  dragOver(e) {
    e.preventDefault()
    e.dataTransfer.dropEffect = "move"
    this.element.classList.add("drag-over")
  }

  dragEnter(e) {
    e.preventDefault()
    this.element.classList.add("drag-over")
  }

  dragLeave(e) {
    // Only remove if we're actually leaving the drop zone (not entering a child)
    if (!this.element.contains(e.relatedTarget)) {
      this.element.classList.remove("drag-over")
    }
  }

  handleDrop(e) {
    e.preventDefault()
    this.element.classList.remove("drag-over")

    const targetDate = this.element.dataset.giorno

    // Handle tappa-to-day drag (from calendar)
    const tappaId = e.dataTransfer.getData("application/tappa-id")
    if (tappaId) {
      this.updateTappaDate(tappaId, targetDate)
      return
    }

    // Handle school-to-day drag (from slideover — legacy)
    const schoolId = e.dataTransfer.getData("text/plain")
    const schoolElement = document.querySelector(`[data-school-id="${schoolId}"]`)
    if (!schoolElement) return

    const tappableType = schoolElement.dataset.tappableType || "ImportScuola"
    const existingTappaId = schoolElement.dataset.tappaId

    if (existingTappaId && existingTappaId !== "null" && existingTappaId !== "") {
      this.updateTappaDate(existingTappaId, targetDate)
    } else {
      this.createTappa(schoolId, tappableType, targetDate)
    }
  }

  async createTappa(schoolId, tappableType, date) {
    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""

    try {
      const response = await fetch(`${prefix}/giri/${this.giroIdValue}/bulk_create_tappe`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          tappable_ids: [schoolId],
          data: date,
          giro_id: this.giroIdValue,
          tappable_type: tappableType
        })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        console.error("Errore nella creazione della tappa")
      }
    } catch (error) {
      console.error("Errore nella richiesta:", error)
    }
  }

  async updateTappaDate(tappaId, newDate) {
    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""

    try {
      const response = await fetch(`${prefix}/tappe/${tappaId}`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({
          tappa: { data_tappa: newDate }
        })
      })

      if (response.ok) {
        // Reload to refresh the calendar with updated tappa positions
        window.location.reload()
      } else {
        console.error("Errore nell'aggiornamento della tappa")
      }
    } catch (error) {
      console.error("Errore nella richiesta:", error)
    }
  }
}
