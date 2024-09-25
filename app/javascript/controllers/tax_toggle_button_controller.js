import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggletax"
export default class extends Controller {

  static targets = ["button", "pushbutton", "field"];

  toggle() {

    this.buttonTarget.classList.toggle("bg-gray-900", "bg-gray-100"); 
    // this.buttonTarget.classList.toggle("bg-gray-100");  

    this.pushbuttonTarget.classList.toggle("translate-x-0")
    this.pushbuttonTarget.classList.toggle("translate-x-5");

    this.fieldTarget.value === "si" ? this.fieldTarget.value = "no" : this.fieldTarget.value = "si";

    this.submit();
    
  }

  submit() {

    const form = this.element.closest("form")
    const formData = new FormData(form);

    const params = new URLSearchParams(formData);
    const newUrl = `${form.action}?${params.toString()}`;

    Turbo.visit(newUrl, { frame: "search_results", action: "advance" });
  }

}
