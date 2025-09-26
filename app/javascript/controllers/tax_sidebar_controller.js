import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-sidebar"
export default class extends Controller {

  static targets = ["element"];
  static values = { open: Boolean };

  connect() {
    console.log("tax-sidebar connected");
  }

  toggle(event) {
    console.log("tax-sidebar toggle");
    event.preventDefault();

    this.elementTargets.forEach((element) => {
      element.classList.toggle("hidden");
    });
  }
}
