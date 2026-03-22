import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]
  selectGroup(e) {
    e.preventDefault()
    e.stopPropagation()
    const details = e.currentTarget.closest("details")
    details.querySelectorAll('input[type="checkbox"]').forEach(cb => {
      cb.checked = true
    })
    this.notifyChange()
  }

  deselectGroup(e) {
    e.preventDefault()
    e.stopPropagation()
    const details = e.currentTarget.closest("details")
    details.querySelectorAll('input[type="checkbox"]').forEach(cb => {
      cb.checked = false
    })
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
