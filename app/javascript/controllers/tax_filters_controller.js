import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-filters"
export default class extends Controller {

  static targets = [ "form" ];

  submit() {
    this.formTarget.requestSubmit();
  }

}
