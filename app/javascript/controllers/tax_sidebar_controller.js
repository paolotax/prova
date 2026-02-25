import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-sidebar"
export default class extends Controller {

  static targets = ["element"];

  connect() {
  }

  toggle(event) {
    event.preventDefault();

    this.elementTargets.forEach((element) => {
      element.classList.toggle("active");
    });
  }

  stopPropagation(event) {
    event.stopPropagation();
  }
}
