import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="toggletax"
export default class extends Controller {

  static targets = ["button"];
  
  toggle(event) {

    let searchParams = new URL(window.location.href).searchParams;

    console.log(searchParams);

    this.buttonTargets.forEach((el) => {      

      if (el.classList.contains("bg-indigo-600")) {
        el.classList.remove("bg-indigo-600");
        el.classList.add("bg-gray-200");
      } else if (el.classList.contains("bg-gray-200")) {
        el.classList.remove("bg-gray-200");
        el.classList.add("bg-indigo-600");
      } else if (el.classList.contains("translate-x-0")) {
        el.classList.remove("translate-x-0")
        el.classList.add("translate-x-5");
      } else {
        el.classList.remove("translate-x-5")
        el.classList.add("translate-x-0");
      }
      
    });

  }
}
