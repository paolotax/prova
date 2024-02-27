import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-dropdown"
export default class extends Controller {
  static targets = ["menu"];

  toggle(event) {
    // event.preventDefault();
    this.menuTarget.classList.toggle("hidden");
  }
}
