import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    // Find the input if not explicitly targeted
    if (!this.hasInputTarget) {
      this.inputElement = this.element.querySelector("input[type='search'], input[type='text']")
    }
  }

  focus(event) {
    const input = this.hasInputTarget ? this.inputTarget : this.inputElement

    // Don't focus if we're already in an input
    if (event.target.closest("input, textarea, trix-editor")) return

    if (input) {
      event.preventDefault()
      input.focus()
      input.select()
    }
  }

  search() {
    // Debounced search could be implemented here
    // For now, form submit handles it
  }
}
