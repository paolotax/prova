import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["combobox"];
  static values = { focus: String };

  connect(e) {
    if (this.focusValue == "now") {
      console.log("focus");
      
      // Clear any existing focus first
      if (document.activeElement && document.activeElement !== this.element) {
        document.activeElement.blur();
      }
      
      // Use multiple requestAnimationFrame calls to ensure proper timing
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          // Find the actual input element within the combobox
          const inputElement = this.comboboxTarget.querySelector('input[role="combobox"]');
          const targetElement = inputElement || this.comboboxTarget;
          
          // Only focus if the element is not already focused and is focusable
          if (targetElement !== document.activeElement && targetElement.focus) {
            try {
              targetElement.focus();
              console.log("Focus applied successfully to", targetElement);
            } catch (error) {
              // Silently handle focus errors (like when blocked by browser)
              console.log("Focus was blocked by browser");
            }
          }
        });
      });
    }
  }
}
