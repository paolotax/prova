import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="queryopt"
export default class extends Controller {
  
  static targets = ["button", "acquistare", "parole"]

  submit() {
    let search_form  = document.getElementById("search_form")
    search_form.requestSubmit();
  }

  updateAcquistare() {
    this.acquistareTarget.value === "si" ? this.acquistareTarget.value = "" : this.acquistareTarget.value = "si";
    this.submit();
  }

  updateParole() {
    this.paroleTarget.value === "any" ? this.paroleTarget.value = "all" : this.paroleTarget.value = "any";
    this.submit();
  }

}
