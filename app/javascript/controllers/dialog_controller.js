import { Controller } from "@hotwired/stimulus";
import { enter, leave } from "controllers/helpers/transitions";

export default class extends Controller {
  static values = { elementId: String }

  connect() {
    enter(this.element).then(() => {
      this.element.focus();
    });
  }

  hide() {
    leave(this.element).then(() => {
      this.element.remove();

      this.#dialogTurboFrame.src = null;
    });
  }

  hideOnSubmit(event) {
    if (event.detail.success) {
      this.hide();
    }
  }

  disconnect() {
    this.#dialogTurboFrame.src = null;
  }

  // private

  get #dialogTurboFrame() {
    return document.querySelector(`turbo-frame[id="${this.elementIdValue}"]`);
  }
}
