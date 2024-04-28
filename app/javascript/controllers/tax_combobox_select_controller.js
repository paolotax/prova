import { Controller } from "@hotwired/stimulus"


// Connects to data-controller="tax-combobox-select"
export default class extends Controller {
  
  static targets = ["combobox"]
  
  connect() {
    console.log("Hello, Stimulus!", this.element)
  }

  // Called when the combobox value changes
  change(event) {
    

    console.log("Combobox target", this.element)

    let scuola_id = document.querySelector("#adozione_import_scuola_id-hw-hidden-field").value;
    let url = `/import_scuole/${scuola_id}/combobox_classi`;
    
    Turbo.visit(url, { frame: "combobox_classi", turbo: true, acceptsStreamResponse: true }) 

    console.log("Combobox value changed", url)

    
  }
}
