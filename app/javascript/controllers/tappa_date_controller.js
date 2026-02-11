import { Controller } from "@hotwired/stimulus"

// Handles school-to-day drag from slideover only.
// Tappa-to-tappa reordering/moving is handled by tax-sortable controller.
export default class extends Controller {
  static values = {
    giroId: Number,
    date: String
  }

  handleDrop(e) {
    e.preventDefault()
    this.element.classList.remove("drag-over")

    const targetDate = this.element.dataset.giorno

    // Handle school-to-day drag (from slideover)
    const schoolId = e.dataTransfer.getData("text/plain")
    const schoolElement = document.querySelector(`[data-school-id="${schoolId}"]`)
    if (!schoolElement) return

    const tappableType = schoolElement.dataset.tappableType || "Scuola"
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

      if (!response.ok) {
        console.error("Errore nell'aggiornamento della tappa")
      }
    } catch (error) {
      console.error("Errore nella richiesta:", error)
    }
  }
}
