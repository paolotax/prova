import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-sidebar"
export default class extends Controller {

  static targets = ["element"];

  connect() {
    console.log("tax-sidebar connected");
    // Listen for custom toggle events
    document.addEventListener("sidebar:toggle", this.handleToggle.bind(this));
  }

  disconnect() {
    console.log("tax-sidebar disconnected");
    document.removeEventListener("sidebar:toggle", this.handleToggle.bind(this));
  }

  toggle(event) {
    console.log("tax-sidebar toggle");
    event.preventDefault();
    this.performToggle();
  }

  handleToggle(event) {
    console.log("tax-sidebar handleToggle from custom event");
    this.performToggle();
  }

  performToggle() {
    this.elementTargets.forEach((element) => {
      element.classList.toggle("hidden");
    });
  }
}
