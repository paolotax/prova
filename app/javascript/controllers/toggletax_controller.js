import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggletax"
export default class extends Controller {

  static targets = ["button", "pushbutton"];


  updateParams(event) {

    let acquistare   = document.getElementById("da_acquistare");
    let search_query = document.getElementById("search_query");
    let search_form  = document.getElementById("search_form")

    if (search_query.value == "any") {
      search_query.value = "all";
    } else {
      search_query.value = "any";
    };

    if (acquistare.value == "si") {
      acquistare.value = "";
    } else {
      acquistare.value = "si";
    }

    
    // let searchParams = new URL(window.location.href).searchParams
    // searchParams.set("da_acquistare", this.acquistareTarget.value)
    // searchParams.set("search_query", this.paroleTarget.value)
    // Turbolinks.visit(window.location.pathname + "?" + searchParams.toString())

    // searchParams.set("acquistare", "no");
    // searchParams.set("search_query", "any");
    search_form.requestSubmit();

  }
  
  toggle() {

    this.buttonTarget.classList.toggle("bg-gray-900"); 
    this.buttonTarget.classList.toggle("bg-gray-200");  

    this.pushbuttonTarget.classList.toggle("translate-x-0")
    this.pushbuttonTarget.classList.toggle("translate-x-5");
  
  }
}
