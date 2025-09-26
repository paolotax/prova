import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-toggle"
export default class extends Controller {

  toggle(event) {
    console.log("sidebar-toggle dispatching event");
    event.preventDefault();

    // Dispatch custom event that sidebar controller will listen for
    document.dispatchEvent(new CustomEvent("sidebar:toggle"));
  }
}