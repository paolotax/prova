import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-select-libro"
export default class extends Controller {

  static targets = ["combobox", "prezzo"]

  connect() {
  }

  change(event) {

    let riga = 20;
    let interpolatedString = `documento_documento_righe_attributes_${riga}_riga_attributes_libro_id-hw-hidden-field`;
    
    let input = document.querySelector(`#${interpolatedString}`);

    this.prezzoTarget.value = input.value;
    console.log("change", input.value);

    // let input = document.querySelector("#appunto_import_scuola_id-hw-hidden-field");
    // if (input == null) {
    //   input = document.querySelector("#adozione_import_scuola_id-hw-hidden-field");  
    // };
    // if (input == null) {
    //   return;
    // };

    // let scuola_id = input.value;
    // if (scuola_id == "") {
    //   return;
    // };
    // let url = `/import_scuole/${scuola_id}/combobox_libri`;
    
    // fetch(url, {
    //   method: "GET",
    //   headers: {
    //     Accept: "text/vnd.turbo-stream.html"
    //   }
    // })
    // .then(r => r.text())
    // .then(html => Turbo.renderStreamMessage(html))
    
    // // // html: <turbo-stream action="replace"> ...</turbo-stream>
  }
}
