import { Controller } from "@hotwired/stimulus"
import { patch, destroy } from "@rails/request.js"

export default class extends Controller {
  static targets = ["body", "giroFilter", "trash"]

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
    const prefix = this.accountPrefix

    for (const item of items) {
      const tappaId = item.id || item
      const calendarCard = document.getElementById(`tappa_${tappaId}`)
      if (calendarCard) calendarCard.remove()

      await patch(`${prefix}/tappe/${tappaId}/sort`, {
        body: JSON.stringify({ data_tappa: null, position: 0 }),
        contentType: "application/json"
      })
    }

    const frame = this.element.closest("turbo-frame")
    if (frame) frame.reload()
  }

  // Trash drop zone — delete tappa
  trashOver(event) {
    if (event.dataTransfer.types.includes("application/x-tappa-ids")) {
      event.preventDefault()
      this.trashTarget.classList.add("agenda-planner__trash--active")
    }
  }

  trashLeave() {
    this.trashTarget.classList.remove("agenda-planner__trash--active")
  }

  async trashDrop(event) {
    event.preventDefault()
    this.trashTarget.classList.remove("agenda-planner__trash--active")

    const raw = event.dataTransfer.getData("application/x-tappa-ids")
    if (!raw) return

    const items = JSON.parse(raw)
    const prefix = this.accountPrefix

    for (const item of items) {
      const tappaId = item.id || item

      // Remove from DOM
      const plannerCard = document.querySelector(`.agenda-planner__tappa[data-tappa-id="${tappaId}"]`)
      if (plannerCard) {
        const direzione = plannerCard.closest(".agenda-planner__direzione")
        plannerCard.remove()
        if (direzione && !direzione.querySelector(".agenda-planner__tappa")) {
          direzione.remove()
        }
      }

      await destroy(`${prefix}/tappe/${tappaId}`, {
        contentType: "application/json"
      })
    }

    // Update badge
    const badge = document.querySelector(".agenda-planner__title .badge")
    if (badge) {
      badge.textContent = document.querySelectorAll(".agenda-planner__tappa").length
    }
  }

  filterGiro(event) {
    const giroId = event.target.value
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    const prefix = this.accountPrefix
    frame.src = giroId
      ? `${prefix}/agenda/planner?giro_id=${giroId}`
      : `${prefix}/agenda/planner`
  }

  get accountPrefix() {
    const match = window.location.pathname.match(/^(\/[0-9a-f-]{36})/)
    return match ? match[1] : ""
  }
}
