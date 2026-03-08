import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["picker"]
  static values = { basePath: { type: String, default: "/agenda" } }

  open() {
    this.pickerTarget.showPicker()
  }

  change() {
    const selectedDate = this.pickerTarget.value
    if (selectedDate) {
      Turbo.visit(`${this.basePathValue}/${selectedDate}`)
    }
  }
}
