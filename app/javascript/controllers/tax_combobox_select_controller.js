import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-select"
export default class extends Controller {
  
  static targets = ["combobox"]

  check(event) {
    this.idlibro = document.querySelector("#adozione_import_scuola_id-hw-hidden-field").value;
    console.log("check", scuola_id);
  }

  // Called when the combobox value changes
  change(event) {
    let scuola_id = document.querySelector("#adozione_import_scuola_id-hw-hidden-field").value;    
    let url = `/import_scuole/${scuola_id}/combobox_classi`;
    
    fetch(url, {
      method: "GET",
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
    
    // html: <turbo-stream action="replace"> ...</turbo-stream>

    console.log("change", scuola_id);
  }
}

