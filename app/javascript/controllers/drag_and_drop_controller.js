import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "container" ]
  static classes = [ "draggedItem", "hoverContainer" ]

  // Actions

  async dragStart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.dropEffect = "move"
    event.dataTransfer.setData("37ui/move", event.target)

    await nextFrame()
    this.dragItem = this.#itemContaining(event.target)
    this.sourceContainer = this.#containerContaining(this.dragItem)
    this.originalDraggedItemCssVariable = this.#containerCssVariableFor(this.sourceContainer)
    this.dragItem.classList.add(this.draggedItemClass)
  }

  dragOver(event) {
    event.preventDefault()
    if (!this.dragItem) { return }

    const container = this.#containerContaining(event.target)
    this.#clearContainerHoverClasses()

    if (!container) { return }

    if (container !== this.sourceContainer) {
      container.classList.add(this.hoverContainerClass)
      this.#applyContainerCssVariableToDraggedItem(container)
    } else {
      this.#restoreOriginalDraggedItemCssVariable()
    }
  }

  async drop(event) {
    const targetContainer = this.#containerContaining(event.target)

    if (!targetContainer || targetContainer === this.sourceContainer) { return }

    this.wasDropped = true
    const count = this.#itemCount(this.dragItem)
    this.#modifyCounter(targetContainer, c => c + count)
    this.#modifyCounter(this.sourceContainer, c => Math.max(0, c - count))

    const sourceContainer = this.sourceContainer
    const sourceParentProv = this.dragItem.closest(".accordion-provincia")
    this.#insertDraggedItem(targetContainer, this.dragItem)
    this.#cleanupEmptyProvincia(sourceParentProv)
    await this.#submitDropRequest(this.dragItem, targetContainer)
    this.#reloadSourceFrame(sourceContainer)
    this.#reloadTargetFrame(targetContainer)
  }

  dragEnd() {
    this.dragItem.classList.remove(this.draggedItemClass)
    this.#clearContainerHoverClasses()

    if (!this.wasDropped) {
      this.#restoreOriginalDraggedItemCssVariable()
    }

    this.sourceContainer = null
    this.dragItem = null
    this.wasDropped = false
    this.originalDraggedItemCssVariable = null
  }

  #itemContaining(element) {
    return element.closest("[data-drag-and-drop-target='item']")
  }

  #containerContaining(element) {
    return this.containerTargets.find(container => container.contains(element) || container === element)
  }

  #clearContainerHoverClasses() {
    this.containerTargets.forEach(container => container.classList.remove(this.hoverContainerClass))
  }

  #applyContainerCssVariableToDraggedItem(container) {
    const cssVariable = this.#containerCssVariableFor(container)
    if (cssVariable) {
      this.dragItem.style.setProperty(cssVariable.name, cssVariable.value)
    }
  }

  #restoreOriginalDraggedItemCssVariable() {
    if (this.originalDraggedItemCssVariable) {
      const { name, value } = this.originalDraggedItemCssVariable
      this.dragItem.style.setProperty(name, value)
    }
  }

  #containerCssVariableFor(container) {
    const { dragAndDropCssVariableName, dragAndDropCssVariableValue } = container.dataset
    if (dragAndDropCssVariableName && dragAndDropCssVariableValue) {
      return { name: dragAndDropCssVariableName, value: dragAndDropCssVariableValue }
    }
    return null
  }

  #itemCount(item) {
    const cards = item.querySelectorAll("[data-drag-and-drop-target='item']")
    return cards.length > 0 ? cards.length : 1
  }

  #modifyCounter(container, fn) {
    const counterElement = container.querySelector("[data-drag-and-drop-counter]")
    if (counterElement) {
      const currentValue = counterElement.textContent.trim()

      if (!/^\d+$/.test(currentValue)) return

      const newValue = fn(parseInt(currentValue))
      counterElement.textContent = newValue
    }
  }

  #insertDraggedItem(container, item) {
    const itemContainer = container.querySelector("[data-drag-drop-item-container]")
    const id = item.dataset.id || ""

    // Provincia dragged — merge gradi into existing provincia or append
    if (id.startsWith("prov:")) {
      const provincia = id.split(":")[1]
      const existing = this.#findProvincia(itemContainer, provincia)

      if (existing) {
        // Move each grado into the existing provincia
        for (const grado of [...item.querySelectorAll(":scope > .accordion-grado")]) {
          existing.append(grado)
        }
        item.remove()
        this.#updateProvinciaCount(existing)
      } else {
        itemContainer.append(item)
      }
      return
    }

    // Grado dragged into a column — find or create parent provincia
    if (id.startsWith("group:")) {
      const provincia = id.split(":")[1]
      let provDetails = this.#findProvincia(itemContainer, provincia)

      if (!provDetails) {
        provDetails = document.createElement("details")
        provDetails.className = "accordion-provincia"
        provDetails.dataset.dragAndDropTarget = "item"
        provDetails.dataset.id = `prov:${provincia}`
        provDetails.innerHTML = `<summary class="accordion-summary accordion-summary--provincia" draggable="true">
          <span class="accordion-label">${provincia}</span>
          <span class="accordion-count"></span>
        </summary>`
        itemContainer.append(provDetails)
      }

      provDetails.append(item)
      this.#updateProvinciaCount(provDetails)
      return
    }

    itemContainer.append(item)
  }

  #findProvincia(itemContainer, provincia) {
    for (const details of itemContainer.querySelectorAll(":scope > .accordion-provincia")) {
      const label = details.querySelector(":scope > summary .accordion-label")
      if (label && label.textContent.trim() === provincia) return details
    }
    return null
  }

  #updateProvinciaCount(provDetails) {
    const countEl = provDetails.querySelector(":scope > summary .accordion-count")
    if (!countEl) return

    const cards = provDetails.querySelectorAll(".card")
    countEl.textContent = cards.length
  }

  #cleanupEmptyProvincia(provDetails) {
    if (!provDetails) return

    // Update count after removal
    this.#updateProvinciaCount(provDetails)

    // Remove provincia if no more grado groups inside
    const remaining = provDetails.querySelectorAll(".accordion-grado")
    if (remaining.length === 0) {
      provDetails.remove()
    }
  }

  async #submitDropRequest(item, container) {
    const body = new FormData()
    const id = item.dataset.id
    const url = container.dataset.dragAndDropUrl.replaceAll("__id__", id)

    // Passa l'agente di origine per distinguere spostamento da assegnazione
    if (this.sourceContainer) {
      const sourceUrl = this.sourceContainer.dataset.dragAndDropUrl || ""
      const match = sourceUrl.match(/membership_id=([^&]+)/)
      if (match) body.append("source_membership_id", match[1])
    }

    return post(url, { body, headers: { Accept: "text/vnd.turbo-stream.html" } })
  }

  #reloadSourceFrame(sourceContainer) {
    const frame = sourceContainer.querySelector("[data-drag-and-drop-refresh]")
    if (frame) frame.reload()
  }

  #reloadTargetFrame(targetContainer) {
    const frame = targetContainer.querySelector("[data-drag-and-drop-refresh]")
    if (frame) frame.reload()
  }
}
