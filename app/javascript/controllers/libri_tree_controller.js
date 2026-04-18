import { Controller } from "@hotwired/stimulus"

// Lista selezionabile dei libri per il wizard giro (kit_adozioni).
// Gerarchia classe → disciplina → libro con toggle per gruppo.
//
// Targets:
//   - selectedCount: elementi il cui textContent viene aggiornato col numero di libri selezionati
//   - submit: button il cui disabled viene aggiornato sulla base della selezione
export default class extends Controller {
  static targets = ["selectedCount", "submit"]

  connect() {
    this.notifyChange()
  }

  toggleGroup(e) {
    e.preventDefault()
    e.stopPropagation()
    const button = e.currentTarget
    const details = button.closest("details")
    const checkboxes = details.querySelectorAll('input[name="libro_ids[]"]:not(:disabled)')
    const allChecked = [...checkboxes].every(cb => cb.checked)

    checkboxes.forEach(cb => { cb.checked = !allChecked })
    button.textContent = allChecked ? "seleziona" : "deseleziona"
    this.notifyChange()
  }

  notifyChange() {
    const count = this.checkedCount()

    this.selectedCountTargets.forEach(t => { t.textContent = count })

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = count === 0
    }

    // Broadcast su event bus locale così il wizard controller può leggere il count
    this.element.dispatchEvent(new CustomEvent("libri-tree:change", {
      bubbles: true,
      detail: { count }
    }))
  }

  checkedCount() {
    return this.element
      .querySelectorAll('input[name="libro_ids[]"]:checked:not(:disabled)')
      .length
  }
}
