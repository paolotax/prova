import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  closeBackground(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  close() {
    this.element.parentElement.removeAttribute("src")
    this.element.remove()
  }
}
