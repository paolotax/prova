import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    window.addEventListener("beforeunload", this.#confirmRefresh);
  }

  disconnect() {
    window.removeEventListener("beforeunload", this.#confirmRefresh);
  }

  // private

  #confirmRefresh(event) {
    event.preventDefault();

    event.returnValue = "";
  }
}
