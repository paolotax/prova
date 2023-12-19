import { Controller } from "@hotwired/stimulus"
import { enter, leave, toggle } from "el-transition";

// Connects to data-controller="sidebar"
export default class extends Controller {
  
  static targets = ["element"];

  openSidebar() {   
    console.log("open sidebar")
    this.elementTargets.forEach((element) => { 
      enter(element);
    });
  }
 
  closeSidebar(event) {
    // event.preventDefault();  
    
    console.log("close sidebar");
    
    this.elementTargets.forEach((element) => {      
      leave(element);
    });

    // setTimeout(() => {
    //   // this.redirect(event.target.href);
    //   window.location.href = event.target.href;
    // }, 300);

  }

  toggleSidebar() {  
    console.log("toggle");
    this.elementTargets.forEach((element) => {
      toggle(element);
    });
  }
}
