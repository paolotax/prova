import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-sidebar"
export default class extends Controller {

  static targets = ["element"];
  static values = { open: Boolean };

  connect() {
    console.log("tax-sidebar connected");
    // Restore previous state from sessionStorage
    this.restoreState();
  }

  disconnect() {
    console.log("tax-sidebar disconnected");
    // Save current state before disconnect
    this.saveState();
  }

  toggle(event) {
    console.log("tax-sidebar toggle");
    event.preventDefault();

    this.elementTargets.forEach((element) => {
      element.classList.toggle("hidden");
    });

    // Save state after toggle
    this.saveState();
  }

  saveState() {
    const isOpen = this.elementTargets.some(el => !el.classList.contains("hidden"));
    sessionStorage.setItem("tax-sidebar-open", isOpen.toString());
  }

  restoreState() {
    const wasOpen = sessionStorage.getItem("tax-sidebar-open") === "true";

    this.elementTargets.forEach((element) => {
      if (wasOpen) {
        element.classList.remove("hidden");
      } else {
        element.classList.add("hidden");
      }
    });
  }
}
