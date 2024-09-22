import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggletax"
export default class extends Controller {

  static targets = ["button", "pushbutton", "field"];

  toggle() {

    this.buttonTarget.classList.toggle("bg-gray-900"); 
    this.buttonTarget.classList.toggle("bg-red-500");  

    this.pushbuttonTarget.classList.toggle("translate-x-0")
    this.pushbuttonTarget.classList.toggle("translate-x-5");

    this.fieldTarget.value === "si" ? this.fieldTarget.value = "no" : this.fieldTarget.value = "si";

    let form = this.element.closest("form")
    form.requestSubmit();

  }

}
