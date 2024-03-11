import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-select-all"
export default class extends Controller {
    static targets = ["parent", "child"]
    connect() {
      // set all to false on page refresh
      console.log("connected")
      this.childTargets.map(x => x.checked = false)
      this.parentTarget.checked = false
    }
  
    toggleChildren() {
      if (this.parentTarget.checked) {
        this.childTargets.map(x => x.checked = true)
        // this.childTargets.forEach((child) => {
        //   child.checked = true
        // })
      } else {
        this.childTargets.map(x => x.checked = false)
      }
    }
  
    toggleParent() {
      if (this.childTargets.map(x => x.checked).includes(false)) {
        this.parentTarget.checked = false
      } else {
        this.parentTarget.checked = true
      }
    }
  }

