import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["select"]
  static values = { basePath: { type: String, default: "/agenda" } }

  change(event) {
    const selectedDate = event.target.value
    if (selectedDate) {
      Turbo.visit(`${this.basePathValue}/${selectedDate}`)
    }
  }
}
