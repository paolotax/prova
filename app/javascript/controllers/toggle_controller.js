import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String }

  toggle() {
    const target = document.getElementById(this.targetValue)
    if (target) target.hidden = !target.hidden
  }
}
