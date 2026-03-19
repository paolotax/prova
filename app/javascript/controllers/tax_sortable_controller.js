import { Controller } from "@hotwired/stimulus"
import { patch } from '@rails/request.js'

// Native HTML5 drag-and-drop reorder controller (replaces SortableJS)
// Works on iOS Safari with the native "+" green circle indicator
export default class extends Controller {
  static values = {
    group: String
  }

  // Wired via data-action on the container element in the view
  dragStart(event) {
    const item = event.target.closest("[draggable='true']")
    if (!item || item.parentElement !== this.element) return

    this.dragItem = item
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dropEffect = "move"

    // Set tappa data for cross-container drops (planner, day-drag)
    const tappaId = item.dataset.tappaId
    if (tappaId) {
      const name = item.querySelector(".tappa-compact__name")?.textContent?.trim() ||
                   item.querySelector(".card__title")?.textContent?.trim() || ""
      event.dataTransfer.setData("application/x-tappa-ids", JSON.stringify([{ id: tappaId, name }]))
    }

    requestAnimationFrame(() => {
      item.classList.add("tax-sortable--dragging")
    })
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    if (!this.dragItem) return

    const target = this.#closestItem(event.target)
    if (!target || target === this.dragItem) return

    const rect = target.getBoundingClientRect()
    const midY = rect.top + rect.height / 2
    const after = event.clientY > midY

    if (after) {
      target.after(this.dragItem)
    } else {
      target.before(this.dragItem)
    }
  }

  dragEnter(event) {
    event.preventDefault()
    // Accept drops from other tax-sortable containers in the same group
    this.element.classList.add("tax-sortable--drop-target")
  }

  dragLeave(event) {
    if (!this.element.contains(event.relatedTarget)) {
      this.element.classList.remove("tax-sortable--drop-target")
    }
  }

  drop(event) {
    event.preventDefault()
    this.element.classList.remove("tax-sortable--drop-target")

    // Handle drops from other tax-sortable containers
    if (!this.dragItem) {
      const data = event.dataTransfer.getData("application/x-tappa-ids")
      if (!data) return
      // Cross-container drops are handled by other controllers (tappa-date, agenda-planner)
      return
    }

    // If item was moved to a different container, append it here
    if (this.dragItem.parentElement !== this.element) {
      const target = this.#closestItem(event.target)
      if (target) {
        const rect = target.getBoundingClientRect()
        const after = event.clientY > rect.top + rect.height / 2
        after ? target.after(this.dragItem) : target.before(this.dragItem)
      } else {
        this.element.appendChild(this.dragItem)
      }
    }

    this.#submitPosition(this.dragItem)
    this.#updateBoardPositions(this.element)
  }

  dragEnd(event) {
    if (this.dragItem) {
      this.dragItem.classList.remove("tax-sortable--dragging")

      // If dropped on a different container, submit position there
      if (this.dragItem.parentElement !== this.element) {
        this.#submitPosition(this.dragItem)
        this.#updateBoardPositions(this.dragItem.parentElement)
        this.#updateBoardPositions(this.element)
      }

      this.dragItem = null
    }
  }

  // Private

  #closestItem(el) {
    while (el && el !== this.element) {
      if (el.parentElement === this.element && el.hasAttribute("draggable")) return el
      el = el.parentElement
    }
    return null
  }

  #submitPosition(item) {
    const url = item.dataset.taxSortableUpdateUrl
    if (!url) return

    const dataTappa = item.parentElement.dataset.taxSortableDataTappa
    const siblings = Array.from(item.parentElement.querySelectorAll(":scope > [draggable]"))
    const newPosition = siblings.indexOf(item) + 1

    patch(url, {
      body: JSON.stringify({ position: newPosition, data_tappa: dataTappa ?? null })
    })
  }

  #updateBoardPositions(container) {
    container.querySelectorAll(":scope > *").forEach((item, index) => {
      const boardId = item.querySelector(".card__id-small")
      if (boardId) boardId.textContent = index + 1
    })
  }
}
