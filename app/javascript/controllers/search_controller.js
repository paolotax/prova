

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search"
export default class extends Controller {
  
  static targets = [ "search" ]


  connect() {
    console.log("this")
  }

  search() {

    clearTimeout(this.timeout);
    
    this.timeout = setTimeout(() => {
        this.formTarget.requestSubmit();
    }, 200);

  }

}
