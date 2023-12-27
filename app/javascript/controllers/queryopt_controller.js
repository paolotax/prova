import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="queryopt"
export default class extends Controller {
  
  static targets = ["aquistare", "parole"]

  connect() {
    console.log("connect");
  }

  submit(event) {
    console.log("submit")
    // event.preventDefault()
    // let searchParams = new URL(window.location.href).searchParams
    // searchParams.set("da_acquistare", this.acquistareTarget.value)
    // searchParams.set("search_query", this.paroleTarget.value)
    // Turbolinks.visit(window.location.pathname + "?" + searchParams.toString())
  }

  updateQuery(event) {


    
    // let searchParams = new URL(event.detail.url).searchParams

    // this.acquistareTarget.value = searchParams.get("da_acquistare")
    // this.paroleTarget.value = searchParams.get("search_query")

    console.log(this.element)
  }
}
