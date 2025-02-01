import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.selectTarget.value = this.selectTarget.dataset.currentDate
  }

  change(event) {
    const selectedDate = event.target.value
    if (selectedDate) {
      Turbo.visit(`/agenda/${selectedDate}`)
    }
  }
} 