import { Controller } from "@hotwired/stimulus"
import {toggle} from "el-transition";

// Connects to data-controller="menu"
export default class extends Controller {
  
  static targets = ["sidebarMenu"];
  
  toggleSidebarMenu() {
    toggle(this.sidebarMenuTarget);
  }

}
