import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-filters"
export default class extends Controller {

  static targets = [ "form" ];

  submit() {
    // this.formTarget.requestSubmit();

    const form = this.formTarget;
    // const form = this.element.closest("form")
    const formData = new FormData(form);

    const params = new URLSearchParams(formData);
    const newUrl = `${form.action}?${params.toString()}`;

    Turbo.visit(newUrl, { frame: "search_results", action: "advance" });

  }

}
