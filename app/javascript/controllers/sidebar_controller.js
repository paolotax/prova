import { Controller } from "@hotwired/stimulus"
import {toggle} from "el-transition";

// Connects to data-controller="sidebar"
export default class extends Controller {
  
  static targets = ["element"];

  toggleSidebar(event) {
    event.preventDefault();
    this.elementTargets.forEach((element) => {
      toggle(element);
    });
  }
}
