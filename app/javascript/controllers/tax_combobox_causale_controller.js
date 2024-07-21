import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-causale"
export default class extends Controller {
  static targets = ["combobox", "prezzo"]

  connect() {
  }

  change(event) {
    let causale = this.comboboxTarget.querySelector("input").value;
    let url = `/documenti/nuovo_numero_documento?causale=${causale}`;

    fetch(url, {
      method: "GET",
      contentType: 'application/json',
      hearders: 'application/json'
    })
    .then(response => response.json())
    .then(data => {
      let nuovo_numero_documento = data.numero_documento;
      let clientable_type = data.clientable_type;
      this.prezzoTarget.value = nuovo_numero_documento;
      this.showClientableForm(clientable_type);
    })
    .catch(error => {
      // Handle any errors
      console.error(error);
    });
  }

  showClientableForm(clientable_type) {
    
    let url = `/searches/clientable/new?clientable_type=${clientable_type}`;
    
    fetch(url, {
      method: "GET",
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
    .then(r => r.text())
    .then(html => Turbo.renderStreamMessage(html))
  }
}
