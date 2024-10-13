import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-select-causale"
export default class extends Controller {


  static targets = ["select", "numero", "clientable", "clientableId"]

  connect() {
  }

  change(event) {
    let causale = this.selectTarget.value;
    let url = `/documenti/nuovo_numero_documento?causale=${causale}`;

    fetch(url, {
      method: "GET",
      contentType: 'application/json',
      hearders: 'application/json'
    })
    .then(response => response.json())
    .then(data => {
      let nuovo_numero_documento = data.numero_documento;
      this.numeroTarget.value = nuovo_numero_documento;
      
      let old_clientable_type = this.clientableTarget.value;  
      let new_clientable_type = data.clientable_type;
      
      this.clientableTarget.value = new_clientable_type;

      if (old_clientable_type == new_clientable_type) {
        return;
      }
      
      this.clientableIdTarget.value = "";
    })
    .catch(error => {
      // Handle any errors
      console.error(error);
    });
  }

  // #showClientableForm(clientable_type) {
    
  //   let url = `/searches/clientable/new?clientable_type=${clientable_type}`;
    
  //   fetch(url, {
  //     method: "GET",
  //     headers: {
  //       Accept: "text/vnd.turbo-stream.html"
  //     }
  //   })
  //   .then(r => r.text())
  //   .then(html => Turbo.renderStreamMessage(html))
  // }
}
