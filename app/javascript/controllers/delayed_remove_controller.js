import { Controller } from "@hotwired/stimulus";
import { leave } from "./helpers/transitions";

export default class extends Controller {
  static values = {
    time: { type: Number, default: 8 } // in seconds
  };

  connect() {
    if (this.timeValue == 0) { return; }

    this.timeout = setTimeout(() => { this.remove(); }, this.#transformedTimeValue);
  }

  disconnect() {
    clearTimeout(this.timeout);

    this.remove();
  }

  remove = () => {
    leave(this.element).then(() => {
      this.element.remove();
    });
  };

  // private

  get #transformedTimeValue() {
    return this.timeValue * 1000;
  }
}
