import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-libro"
export default class extends Controller {

  static targets = ["combobox", "prezzo"]

  connect() {
  }

  change(event) {
    let id_libro = this.comboboxTarget.querySelector("input").value;
    let url = `/libri/${id_libro}/get_prezzo_copertina_cents`;

    fetch(url, {
      method: "GET",
      contentType: 'application/json',
      hearders: 'application/json'
    })
    .then(response => response.json())
    .then(data => {
      // Assuming the response contains the prezzo_copertina_cents
      let prezzo_copertina_cents = data.prezzo_copertina_cents;
      // Use the prezzo_copertina_cents as needed
      this.prezzoTarget.value = prezzo_copertina_cents / 100.0;
    })
    .catch(error => {
      // Handle any errors
      console.error(error);
    });
  }
}