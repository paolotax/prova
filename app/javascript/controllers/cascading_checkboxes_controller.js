import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["leaf", "submit"]

  connect() {
    this.updateAll()
  }

  // Click su checkbox padre → toggle tutti i figli selezionabili
  cascadeParent(event) {
    const parent = event.currentTarget
    const container = parent.closest("details")
    const children = container.querySelectorAll('input[type="checkbox"]:not(:disabled)')

    children.forEach(child => {
      if (child !== parent) child.checked = parent.checked
    })

    this.updateAncestors(container)
    this.updateCount()
  }

  // Click su checkbox foglia → aggiorna padri
  cascadeLeaf() {
    this.element.querySelectorAll("[data-parent-checkbox]").forEach(parent => {
      this.syncParent(parent)
    })
    this.updateCount()
  }

  updateAll() {
    const parents = [...this.element.querySelectorAll("[data-parent-checkbox]")]
    parents.sort((a, b) => {
      return this.depth(b) - this.depth(a)
    })
    parents.forEach(parent => this.syncParent(parent))
    this.updateCount()
  }

  // Sincronizza un checkbox padre con lo stato dei figli selezionabili
  syncParent(parentCheckbox) {
    const container = parentCheckbox.closest("details")
    const leaves = container.querySelectorAll('input[name="school_ids[]"]')
    if (leaves.length === 0) {
      parentCheckbox.checked = false
      parentCheckbox.indeterminate = false
      return
    }

    const checked = [...leaves].filter(l => l.checked).length
    if (checked === 0) {
      parentCheckbox.checked = false
      parentCheckbox.indeterminate = false
    } else if (checked === leaves.length) {
      parentCheckbox.checked = true
      parentCheckbox.indeterminate = false
    } else {
      parentCheckbox.checked = false
      parentCheckbox.indeterminate = true
    }

    const counter = parentCheckbox.closest("summary")?.querySelector("[data-count]")
    if (counter) counter.textContent = `${checked}/${leaves.length}`
  }

  updateAncestors(container) {
    let el = container.parentElement?.closest("details")
    while (el) {
      const parent = el.querySelector(":scope > summary [data-parent-checkbox]")
      if (parent) this.syncParent(parent)
      el = el.parentElement?.closest("details")
    }
  }

  updateCount() {
    if (!this.hasSubmitTarget) return
    const total = this.leafTargets.filter(l => l.checked).length
    this.submitTarget.textContent = `Genera ${total} tappe`
    this.submitTarget.disabled = total === 0
  }

  depth(el) {
    let d = 0
    let node = el
    while (node && node !== this.element) {
      if (node.tagName === "DETAILS") d++
      node = node.parentElement
    }
    return d
  }
}
