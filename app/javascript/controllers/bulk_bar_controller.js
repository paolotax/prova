import { Controller } from "@hotwired/stimulus"

/**
 * BulkBarController - manages the bulk actions bar UI
 *
 * Works with bulk_actions_controller which handles checkbox selection.
 * This controller manages showing/hiding forms within the bar.
 */
export default class extends Controller {
  static targets = ["menu", "menuButton", "form", "forms"]

  showForm(event) {
    const formId = event.currentTarget.dataset.formId
    const clickedButton = event.currentTarget

    // Find the target form
    const targetForm = this.formTargets.find(form => form.dataset.formId === formId)

    // If form is already active, hide it
    if (targetForm?.hasAttribute("data-active")) {
      this.hideForm()
      return
    }

    // Hide all forms
    this.formTargets.forEach(form => form.removeAttribute("data-active"))

    // Update button states
    this.menuButtonTargets.forEach(button => {
      button.removeAttribute("aria-expanded")
      if (button !== clickedButton) {
        button.hidden = true
      }
    })

    // Show clicked button as expanded
    clickedButton.setAttribute("aria-expanded", "true")

    // Show target form
    if (targetForm) {
      targetForm.setAttribute("data-active", "")
    }
  }

  hideForm() {
    // Hide all forms
    this.formTargets.forEach(form => form.removeAttribute("data-active"))

    // Show all buttons
    this.menuButtonTargets.forEach(button => {
      button.hidden = false
      button.removeAttribute("aria-expanded")
    })
  }
}
