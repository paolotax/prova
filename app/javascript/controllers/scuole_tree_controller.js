import { Controller } from "@hotwired/stimulus"

// Unifica il comportamento di selezione della lista scuole (wizard + dialog genera tappe).
// Toggle "seleziona/deseleziona" su ogni gruppo (provincia / area) e aggiornamento
// di un contatore e/o submit button opzionali.
//
// Targets:
//   - count: elementi il cui textContent viene aggiornato col numero di checkbox attivi
//   - submit: button/input il cui disabled e (opzionalmente) textContent vengono aggiornati
//
// Values:
//   - submitTemplate: stringa con "{count}" placeholder usato per il testo del submit target
export default class extends Controller {
  static targets = ["count", "submit"]
  static values = { submitTemplate: String }

  connect() {
    this.notifyChange()
  }

  toggleGroup(e) {
    e.preventDefault()
    e.stopPropagation()
    const button = e.currentTarget
    const details = button.closest("details")
    const checkboxes = details.querySelectorAll('input[name="school_ids[]"]:not(:disabled)')
    const allChecked = [...checkboxes].every(cb => cb.checked)

    checkboxes.forEach(cb => { cb.checked = !allChecked })
    button.textContent = allChecked ? "seleziona" : "deseleziona"
    this.notifyChange()
  }

  notifyChange() {
    const count = this.checkedCount()

    this.countTargets.forEach(t => { t.textContent = count })

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = count === 0
      if (this.hasSubmitTemplateValue) {
        this.submitTarget.textContent = this.submitTemplateValue.replace("{count}", count)
        this.submitTarget.value = this.submitTemplateValue.replace("{count}", count)
      }
    }
  }

  checkedCount() {
    return this.element
      .querySelectorAll('input[name="school_ids[]"]:checked:not(:disabled)')
      .length
  }
}
