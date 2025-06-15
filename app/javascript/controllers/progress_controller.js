import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    time: { type: Number, default: 30 } // in seconds
  };

  connect() {
    const startTime =  Date.now();

    this.interval = setInterval(() => {
      const elapsed = Date.now() - startTime;
      const progress = Math.min(elapsed / this.#transformedTimeValue, 1);

      this.element.style.width = `${progress * 100}%`;

      if (progress === 1) clearInterval(this.interval);
    }, 50);
  }

  disconnect() {
    clearInterval(this.interval);
  }

  // private

  get #transformedTimeValue() {
    return this.timeValue * 1000;
  }
}
