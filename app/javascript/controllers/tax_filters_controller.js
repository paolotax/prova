import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-filters"
export default class extends Controller {

  static targets = [ "form" ];

  connect() {
    console.log("Hello, Stimulus!", this.element)
  }

  submit() {
    console.log("submit")
    this.formTarget.requestSubmit();
  }

}
