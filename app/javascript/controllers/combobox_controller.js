import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="combobox"
export default class extends Controller {
  static targets = ["form"];
  connect() {
    this.element.addEventListener(
      "combobox:itemSelected",
      this.handleItemSelected
    );
  }

  disconnect() {
    this.element.removeEventListener(
      "combobox:itemSelected",
      this.handleItemSelected
    );
  }

  handleItemSelected(event) {
    // Assuming "posts-container" is the id of your input element
    const input = document.getElementById("posts-container");

    // Modify the input value as needed, for example, appending a space
    input.value += ""; // Or any other modifications you need

    // Create and dispatch an input event to simulate user typing
    const input_event = new Event("input", {
      bubbles: true,
      cancelable: true,
    });

    input.dispatchEvent(input_event);
  }
}
