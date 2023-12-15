import { Controller } from "@hotwired/stimulus"
import {toggle} from "el-transition";

// Connects to data-controller="menu"
export default class extends Controller {
  
  static targets = ["sidebarMenu"];
  
  toggleSidebarMenu(e) {
    e.preventDefault();
    toggle(this.sidebarMenuTarget);
  }

}
