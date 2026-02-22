import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "icon"]

  toggle() {
    this.rowTargets.forEach(row => row.toggleAttribute("hidden"))
    this.iconTarget.classList.toggle("icon--rotated")
  }
}
