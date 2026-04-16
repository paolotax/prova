import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

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
    const leaves = this.element.querySelectorAll('input[name="school_ids[]"]')
    const total = [...leaves].filter(l => l.checked).length
    if (this.hasSubmitTarget) {
      this.submitTarget.textContent = `Genera ${total} tappe`
      this.submitTarget.disabled = total === 0
    }
  }
}
