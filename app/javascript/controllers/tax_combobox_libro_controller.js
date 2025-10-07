import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-libro"
export default class extends Controller {

  static targets = ["combobox", "prezzo", "quantita", "sconto"]

  change(event) {
    let id_libro = this.comboboxTarget.querySelector("input").value;

    if (id_libro == "") {
      this.prezzoTarget.value = "0.0";
      if (this.hasScontoTarget) {
        this.scontoTarget.value = "0.0";
      }
      return;
    }

    // Trova il clientable_id e type dai data attributes della sezione documento_righe
    let documentoRigheSection = document.querySelector('#documento_righe');
    let clientable_id = documentoRigheSection?.dataset.clientableId || null;
    let clientable_type = documentoRigheSection?.dataset.clientableType || null;

    let url = `/libri/${id_libro}/get_prezzo_e_sconto`;

    // Aggiungi parametri cliente se presenti
    if (clientable_id && clientable_type === 'Cliente') {
      url += `?cliente_id=${clientable_id}`;
    }

    fetch(url, {
      method: "GET",
      contentType: 'application/json',
      hearders: 'application/json'
    })
    .then(response => response.json())
    .then(data => {
      // Assuming the response contains the prezzo_copertina_cents and sconto
      let prezzo_copertina_cents = data.prezzo_copertina_cents;
      let sconto = data.sconto || 0.0;

      // Use the prezzo_copertina_cents as needed
      this.prezzoTarget.value = prezzo_copertina_cents / 100.0;

      // Imposta lo sconto se presente
      if (this.hasScontoTarget) {
        this.scontoTarget.value = sconto;
      }

      this.quantitaTarget.focus();
      this.quantitaTarget.select();
    })
    .catch(error => {
      // Handle any errors
      console.error(error);
    });
  }
}
