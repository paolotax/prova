import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { focus: String };

  connect(e) {
    if (this.focusValue == "now") {
      console.log("focus");
      // this.element.querySelector("input").focus();
      this.element.focus();
      this.element.select();
    }
  }
}
