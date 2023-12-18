import { Controller } from "@hotwired/stimulus"
import { enter, leave, toggle } from "el-transition";

// Connects to data-controller="sidebar"
export default class extends Controller {
  
  static targets = ["element"];

  openSidebar(event) {   
    console.log("open sidebar")
    this.elementTargets.forEach((element) => { 
      enter(element);
    });
  }
 
  closeSidebar(event) {
    console.log("close sidebar");
    this.elementTargets.forEach((element) => {      
      leave(element);
    });
  }

  toggleSidebar(event) {    
    console.log(element.classList.contains("toggle"));
    this.elementTargets.forEach((element) => {
      toggle(element);
    });
  }
}
