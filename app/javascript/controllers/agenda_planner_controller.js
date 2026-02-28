import { Controller } from "@hotwired/stimulus"
import { patch, destroy } from "@rails/request.js"

export default class extends Controller {
  static targets = ["body", "header", "giroFilter", "trash"]

  connect() {
    this.dragging = false
    this.offsetX = 0
    this.offsetY = 0
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp = this.onMouseUp.bind(this)
  }

  // Panel drag — move planner around the screen
  panelDragStart(event) {
    // Don't drag if clicking on select, button, or trash
    if (event.target.closest("select, button, .agenda-planner__trash")) return

    this.dragging = true
    const rect = this.element.getBoundingClientRect()
    this.offsetX = event.clientX - rect.left
    this.offsetY = event.clientY - rect.top

    // Switch to floating with fit-content width
    this.element.classList.add("agenda-planner--floating")
    this.element.style.insetBlockStart = `${rect.top}px`
    this.element.style.insetInlineStart = `${rect.left}px`
    this.element.style.inlineSize = "fit-content"

    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup", this.onMouseUp)
    event.preventDefault()
  }

  onMouseMove(event) {
    if (!this.dragging) return
    this.element.style.insetBlockStart = `${event.clientY - this.offsetY}px`
    this.element.style.insetInlineStart = `${event.clientX - this.offsetX}px`
  }

  onMouseUp() {
    this.dragging = false
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
  }

  // Double-click header to dock back
  panelDock() {
    this.element.classList.remove("agenda-planner--floating")
    this.element.style.insetBlockStart = ""
    this.element.style.insetInlineStart = ""
    this.element.style.inlineSize = ""
  }

  disconnect() {
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
  }

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
