import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["body", "toggle", "tappaCheck", "direzioneCheck", "actionBar", "selectionCount", "dayButtons", "giroFilter"]

  connect() {
    this.selectedTappaIds = new Set()
  }

  toggle() {
    this.element.classList.toggle("agenda-planner--collapsed")
  }

  toggleTappa(event) {
    const tappaId = event.target.dataset.tappaId
    const tappaEl = event.target.closest(".agenda-planner__tappa")

    if (event.target.checked) {
      this.selectedTappaIds.add(tappaId)
      tappaEl.classList.add("selected")
    } else {
      this.selectedTappaIds.delete(tappaId)
      tappaEl.classList.remove("selected")
    }
    this.updateActionBar()
  }

  toggleDirezione(event) {
    const direzioneId = event.target.dataset.direzioneId
    const checked = event.target.checked

    this.tappaCheckTargets.forEach(check => {
      const tappaEl = check.closest(".agenda-planner__tappa")
      if (tappaEl && tappaEl.dataset.direzioneId === direzioneId) {
        check.checked = checked
        const tappaId = check.dataset.tappaId
        if (checked) {
          this.selectedTappaIds.add(tappaId)
          tappaEl.classList.add("selected")
        } else {
          this.selectedTappaIds.delete(tappaId)
          tappaEl.classList.remove("selected")
        }
      }
    })
    this.updateActionBar()
  }

  dragStart(event) {
    const tappaId = event.currentTarget.dataset.tappaId

    if (!this.selectedTappaIds.has(tappaId)) {
      this.clearSelection()
      this.selectedTappaIds.add(tappaId)
      const check = event.currentTarget.querySelector("input[type=checkbox]")
      if (check) check.checked = true
      event.currentTarget.classList.add("selected")
    }

    const ids = Array.from(this.selectedTappaIds)
    event.dataTransfer.setData("application/x-tappa-ids", JSON.stringify(ids))
    event.dataTransfer.effectAllowed = "move"

    this.element.querySelectorAll(".agenda-planner__tappa.selected").forEach(el => {
      el.classList.add("dragging")
    })
  }

  dragEnd() {
    this.element.querySelectorAll(".dragging").forEach(el => {
      el.classList.remove("dragging")
    })
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

  async assignToDay(event) {
    const date = event.currentTarget.dataset.date
    if (!date || this.selectedTappaIds.size === 0) return
    await this.batchAssign(Array.from(this.selectedTappaIds), date)
  }

  async batchAssign(tappaIds, date) {
    const accountMatch = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""

    for (const tappaId of tappaIds) {
      await patch(`${prefix}/tappe/${tappaId}/sort`, {
        body: JSON.stringify({ data_tappa: date, position: 0 }),
        contentType: "application/json"
      })
    }

    const frame = this.element.closest("turbo-frame")
    if (frame) frame.reload()
    window.Turbo.visit(window.location.href, { action: "replace" })
  }

  updateActionBar() {
    const count = this.selectedTappaIds.size
    if (this.hasActionBarTarget) {
      this.actionBarTarget.hidden = count === 0
    }
    if (this.hasSelectionCountTarget) {
      this.selectionCountTarget.textContent = `${count} selezionat${count === 1 ? "a" : "e"}`
    }
    this.updateDayButtons()
  }

  updateDayButtons() {
    if (!this.hasDayButtonsTarget) return

    const dayCells = document.querySelectorAll("[data-giorno]")
    const days = new Map()
    dayCells.forEach(cell => {
      const giorno = cell.dataset.giorno
      if (!days.has(giorno)) days.set(giorno, giorno)
    })

    const today = new Date().toISOString().slice(0, 10)
    const relevantDays = Array.from(days.keys())
      .filter(d => d >= today)
      .slice(0, 10)

    this.dayButtonsTarget.innerHTML = relevantDays.map(d => {
      const date = new Date(d + "T00:00:00")
      const label = date.toLocaleDateString("it-IT", { weekday: "short", day: "numeric" })
      return `<button type="button" class="btn btn--small" data-date="${d}" data-action="agenda-planner#assignToDay">${label}</button>`
    }).join("")
  }

  clearSelection() {
    this.selectedTappaIds.clear()
    this.tappaCheckTargets.forEach(check => {
      check.checked = false
      check.closest(".agenda-planner__tappa")?.classList.remove("selected")
    })
    this.direzioneCheckTargets.forEach(check => check.checked = false)
    this.updateActionBar()
  }
}
