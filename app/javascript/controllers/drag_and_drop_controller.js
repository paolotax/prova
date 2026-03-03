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

    // Compact ghost for table rows (plessi)
    if (event.target.tagName === "TR") {
      this.#setCompactDragImage(event)
    }

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

    // Aggiorna contatori provincia/grado nel target dopo inserimento
    const targetParentProv = this.dragItem.closest(".accordion-provincia")
    if (targetParentProv) this.#updateProvinciaCount(targetParentProv)
    this.#updateCardMeta(this.dragItem, targetContainer)
    this.#updateCardMeta(sourceContainer)
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
    return this.#scuoleCount(item)
  }

  #modifyCounter(container, fn) {
    const counterElements = container.querySelectorAll("[data-drag-and-drop-counter]")
    for (const counterElement of counterElements) {
      const currentValue = counterElement.textContent.trim()

      if (!/^\d+$/.test(currentValue)) continue

      const newValue = fn(parseInt(currentValue))
      counterElement.textContent = newValue
    }
  }

  #insertDraggedItem(container, item) {
    const itemContainer = container.querySelector("[data-drag-drop-item-container]")
    const id = item.dataset.id || ""

    // Single plesso <tr> dragged out of a direzione card
    if (item.tagName === "TR") {
      this.#moveNestedRow(item, itemContainer, container)
      return
    }

    // Provincia dragged — merge into existing or append
    if (id.startsWith("prov:")) {
      const existing = this.#findProvincia(itemContainer, id.split(":")[1])

      if (existing) {
        for (const grado of [...item.querySelectorAll(":scope > .accordion-grado")]) {
          this.#mergeGradoInto(existing, grado)
        }
        item.remove()
        this.#updateProvinciaCount(existing)
      } else {
        itemContainer.append(item)
      }
      return
    }

    // Grado dragged — merge into existing provincia > grado or create
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

      this.#mergeGradoInto(provDetails, item)
      this.#updateProvinciaCount(provDetails)
      return
    }

    // Card inside accordion — insert into matching provincia > grado
    const sourceGrado = item.closest(".accordion-grado")
    const sourceProv = item.closest(".accordion-provincia")

    if (sourceProv && sourceGrado) {
      this.#insertIntoAccordion(item, itemContainer, sourceProv, sourceGrado)

      // Cleanup source grado if empty
      const remainingCards = sourceGrado.querySelectorAll(".accordion-items > article.card")
      if (remainingCards.length === 0) {
        sourceGrado.remove()
      }
      return
    }

    // Flat container (aree): merge or insert sorted
    this.#mergeCardInto(itemContainer, item)
  }

  #insertIntoAccordion(item, targetItemContainer, sourceProv, sourceGrado) {
    const targetItems = this.#ensureAccordion(targetItemContainer, sourceProv, sourceGrado)
    this.#mergeCardInto(targetItems, item)

    const targetProv = targetItemContainer.querySelector(`:scope > [data-id="${sourceProv.dataset.id}"]`)
    if (targetProv) this.#updateProvinciaCount(targetProv)
  }

  // Merge a grado accordion into a provincia — if grado exists, merge cards; otherwise append
  #mergeGradoInto(targetProv, sourceGrado) {
    const gradoId = sourceGrado.dataset.id
    const existingGrado = targetProv.querySelector(`:scope > [data-id="${gradoId}"]`)

    if (existingGrado) {
      const targetItems = existingGrado.querySelector(".accordion-items")
      for (const card of [...sourceGrado.querySelectorAll(".accordion-items > article.card")]) {
        this.#mergeCardInto(targetItems, card)
      }
      sourceGrado.remove()
    } else {
      targetProv.append(sourceGrado)
    }
  }

  // Merge a card into a container — if card with same data-id exists, merge plessi rows; otherwise insert sorted
  #mergeCardInto(targetItems, card) {
    const direzId = card.dataset.id
    const existingCard = direzId ? targetItems.querySelector(`article.card[data-id="${direzId}"]`) : null

    if (existingCard) {
      const targetTbody = existingCard.querySelector("tbody")
      const existingIds = new Set([...targetTbody.querySelectorAll("tr[data-id]")].map(r => r.dataset.id))
      for (const row of [...card.querySelectorAll("tbody tr[data-id]")]) {
        if (!existingIds.has(row.dataset.id)) {
          targetTbody.append(row)
        }
      }
      existingCard.dataset.scuoleCount = targetTbody.querySelectorAll("tr").length
      card.remove()
    } else {
      this.#insertSorted(targetItems, card)
    }
  }

  #insertSorted(container, item) {
    const key = this.#cardSortKey(item)
    if (!key) { container.append(item); return }

    for (const existing of container.children) {
      const existingKey = this.#cardSortKey(existing)
      if (existingKey && key.localeCompare(existingKey, "it") < 0) {
        existing.before(item)
        return
      }
    }
    container.append(item)
  }

  #cardSortKey(el) {
    const comune = el.querySelector(".card__subtitle")?.textContent?.trim() || ""
    const title = el.querySelector(".card__title")?.textContent?.trim() || ""
    return comune ? `${comune}\0${title}` : title || null
  }

  // Find or create provincia > grado accordion in target, returns the .accordion-items container
  #ensureAccordion(targetItemContainer, sourceProv, sourceGrado) {
    const provId = sourceProv.dataset.id
    const gradoId = sourceGrado.dataset.id

    let targetProv = targetItemContainer.querySelector(`:scope > [data-id="${provId}"]`)
    if (!targetProv) {
      targetProv = document.createElement("details")
      targetProv.className = "accordion-provincia"
      targetProv.dataset.dragAndDropTarget = "item"
      targetProv.dataset.id = provId
      targetProv.open = true
      targetProv.innerHTML = sourceProv.querySelector(":scope > summary").outerHTML
      targetItemContainer.append(targetProv)
    }

    let targetGrado = targetProv.querySelector(`:scope > [data-id="${gradoId}"]`)
    if (!targetGrado) {
      targetGrado = document.createElement("details")
      targetGrado.className = "accordion-grado"
      targetGrado.dataset.dragAndDropTarget = "item"
      targetGrado.dataset.id = gradoId
      targetGrado.open = true
      targetGrado.innerHTML = sourceGrado.querySelector(":scope > summary").outerHTML + '<div class="accordion-items"></div>'
      targetProv.append(targetGrado)
    }

    return targetGrado.querySelector(".accordion-items")
  }

  #moveNestedRow(tr, targetItemContainer, targetSection) {
    const sourceCard = tr.closest("article.card")
    const sourceGrado = tr.closest(".accordion-grado")
    const sourceProv = tr.closest(".accordion-provincia")
    const direzId = sourceCard?.dataset.id

    // 1. Remove <tr> from source card, cleanup if empty
    tr.remove()
    if (sourceCard) {
      const remainingRows = sourceCard.querySelectorAll("tbody tr")
      if (remainingRows.length === 0) {
        sourceCard.remove()
      } else {
        sourceCard.dataset.scuoleCount = remainingRows.length
      }
    }

    // 2. Determine target container (accordion or flat)
    const targetItems = (sourceProv && sourceGrado)
      ? this.#ensureAccordion(targetItemContainer, sourceProv, sourceGrado)
      : targetItemContainer

    // 3. Find existing card for this direzione or create one
    let targetCard = direzId ? targetItems.querySelector(`article.card[data-id="${direzId}"]`) : null

    if (targetCard) {
      targetCard.querySelector("tbody").append(tr)
      targetCard.dataset.scuoleCount = targetCard.querySelectorAll("tbody tr").length
      this.#updateCardMetaTotals(targetCard)
    } else if (sourceCard) {
      const newCard = sourceCard.cloneNode(true)
      newCard.querySelectorAll("tbody tr").forEach(r => r.remove())
      newCard.querySelector("tbody").append(tr)
      newCard.dataset.scuoleCount = "1"
      this.#insertSorted(targetItems, newCard)
      this.#updateCardMetaTotals(newCard)
    }

    // 4. Update source card meta totals
    if (sourceCard && sourceCard.isConnected) {
      this.#updateCardMetaTotals(sourceCard)
    }

    // 4b. Update avatar on target card
    const movedCard = targetCard || targetItems.querySelector(`article.card[data-id="${direzId}"]`)
    if (movedCard && targetSection) this.#updateCardMetaAvatar(movedCard, targetSection)

    // 5. Update accordion counts if present
    if (sourceProv && sourceGrado) {
      const targetProv = targetItemContainer.querySelector(`:scope > [data-id="${sourceProv.dataset.id}"]`)
      if (targetProv) this.#updateProvinciaCount(targetProv)
    }
  }

  #findProvincia(itemContainer, provincia) {
    for (const details of itemContainer.querySelectorAll(":scope > .accordion-provincia")) {
      const label = details.querySelector(":scope > summary .accordion-label")
      if (label && label.textContent.trim() === provincia) return details
    }
    return null
  }

  #scuoleCount(element) {
    const cards = element.querySelectorAll(".card[data-scuole-count]")
    if (cards.length === 0) return parseInt(element.dataset.scuoleCount) || 1
    let total = 0
    for (const card of cards) total += parseInt(card.dataset.scuoleCount) || 1
    return total
  }

  #updateProvinciaCount(provDetails) {
    // Aggiorna contatori dei singoli gradi
    for (const grado of provDetails.querySelectorAll(":scope > .accordion-grado")) {
      const gradoCount = grado.querySelector(":scope > summary .accordion-count")
      if (gradoCount) {
        gradoCount.textContent = this.#scuoleCount(grado)
      }
    }

    // Aggiorna contatore provincia (somma di tutte le scuole)
    const countEl = provDetails.querySelector(":scope > summary .accordion-count")
    if (!countEl) return
    countEl.textContent = this.#scuoleCount(provDetails)
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

  // Update card__meta totals and avatar after drag-and-drop
  #updateCardMeta(cardOrContainer, targetContainer) {
    // If called with a container (source), update all cards inside it
    const cards = cardOrContainer.matches?.("article.card")
      ? [cardOrContainer]
      : cardOrContainer.querySelectorAll("article.card")

    for (const card of cards) {
      this.#updateCardMetaTotals(card)
    }

    // Update avatar only for the moved card (when targetContainer is provided)
    if (targetContainer) {
      const card = cardOrContainer.matches?.("article.card") ? cardOrContainer : null
      if (card) this.#updateCardMetaAvatar(card, targetContainer)
    }
  }

  #updateCardMetaTotals(card) {
    const meta = card.querySelector(".card__meta")
    if (!meta) return

    const rows = card.querySelectorAll("tbody tr")
    // Skip isolated schools (no plessi table) — their meta comes from server attributes
    if (rows.length === 0) return

    let totalClassi = 0
    let totalAdozioni = 0

    for (const row of rows) {
      const classiTd = row.querySelector("[data-classi-count]")
      const adozioniTd = row.querySelector("[data-mie-adozioni-count]")
      if (classiTd) totalClassi += parseInt(classiTd.dataset.classiCount) || 0
      if (adozioniTd) totalAdozioni += parseInt(adozioniTd.dataset.mieAdozioniCount) || 0
    }

    const copieSpan = meta.querySelector(".card__meta-text--copie")
    if (copieSpan) {
      copieSpan.innerHTML = totalClassi > 0
        ? `<strong>${totalClassi}</strong> classi`
        : ""
    }

    const importoSpan = meta.querySelector(".card__meta-text--importo")
    if (importoSpan) {
      if (totalAdozioni > 0) {
        const label = totalAdozioni === 1 ? "mia adozione" : "mie adozioni"
        importoSpan.innerHTML = `<strong class="txt-negative">${totalAdozioni} ${label}</strong>`
      } else {
        importoSpan.innerHTML = ""
      }
    }

    // Hide meta if both are 0
    meta.style.display = (totalClassi === 0 && totalAdozioni === 0) ? "none" : ""
  }

  #setCompactDragImage(event) {
    const tr = event.target
    const ghost = document.createElement("div")
    ghost.style.cssText = "position:absolute;top:-9999px;background:var(--surface-1);padding:2px 8px;border-radius:4px;font-size:var(--text-xx-small);white-space:nowrap;max-width:200px;overflow:hidden;text-overflow:ellipsis"

    // Collect visible text from cells
    const parts = []
    for (const td of tr.cells) {
      const text = td.textContent.trim()
      if (text) parts.push(text)
    }
    ghost.textContent = parts.join(" · ")

    document.body.appendChild(ghost)
    event.dataTransfer.setDragImage(ghost, 0, 0)
    requestAnimationFrame(() => ghost.remove())
  }

  #updateCardMetaAvatar(card, container) {
    const avatarHtml = container.dataset.dragAndDropAvatar
    if (!avatarHtml) return

    const avatarDiv = card.querySelector(".card__meta-avatars--author")
    if (avatarDiv) {
      avatarDiv.innerHTML = avatarHtml
    }
  }
}
