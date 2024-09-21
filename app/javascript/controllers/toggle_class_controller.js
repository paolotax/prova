import { Controller } from "@hotwired/stimulus";


export default class extends Controller {
  static classes = ["toggle"];

  connect() {
    console.log("Hello, Stimulus!", this.element);
  }
  toggle() {
    this.element.classList.toggle(...this.toggleClasses);
  }
}
