import { Controller } from "@hotwired/stimulus"

// Toggle between view and edit mode inline
export default class extends Controller {
  static targets = ["view", "edit"]

  showEdit(event) {
    event.preventDefault()
    this.viewTarget.hidden = true
    this.editTarget.hidden = false
  }

  showView(event) {
    if (event) event.preventDefault()
    this.viewTarget.hidden = false
    this.editTarget.hidden = true
  }

  // Called after successful form submission
  afterSubmit() {
    this.showView()
  }
}
