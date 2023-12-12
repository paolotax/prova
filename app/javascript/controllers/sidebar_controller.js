import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  
  static targets = ["element"];

  connect() {
    console.log("ciao");
  };
  
  toggle(event) {
    event.preventDefault();
    this.elementTargets.forEach((element) => {
      console.log("click")
      
      if (element.classList.contains("hidden")) {
        console.log('if')
        element.classList.remove("hidden");
        element.classList.add("block");
      } else {
        console.log('else');
        element.classList.add("hidden");
        element.classList.remove("block");
      }
    });

  }
}
