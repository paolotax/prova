import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-select"
export default class extends Controller {
  
  static targets = ["combobox"]

  check(event) {
    // da eliminare anche data-action 
  }

  change(event) {

    let input = document.querySelector("#appunto_import_scuola_id-hw-hidden-field");
    if (input == null) {
      input = document.querySelector("#adozione_import_scuola_id-hw-hidden-field");  
    };
    if (input == null) {
      return;
    };

    let scuola_id = input.value;
    if (scuola_id == "") {
      return;
    };
    let url = `/import_scuole/${scuola_id}/combobox_classi`;
    
    fetch(url, {
      method: "GET",
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
    
    // // html: <turbo-stream action="replace"> ...</turbo-stream>
  }
}

