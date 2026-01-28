import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-combobox-libro"
export default class extends Controller {

  static targets = ["combobox", "prezzo", "quantita", "sconto"]
  static values = { lastLibroId: String }

  change(event) {
    let id_libro = this.comboboxTarget.querySelector("input").value;

    if (id_libro == "") {
      this.prezzoTarget.value = "0.0";
      if (this.hasScontoTarget) {
        this.scontoTarget.value = "0.0";
      }
      this.lastLibroIdValue = ""
      return;
    }

    // Evita chiamate ripetute se il libro non è cambiato
    if (id_libro === this.lastLibroIdValue) {
      this.quantitaTarget.focus();
      this.quantitaTarget.select();
      return;
    }

    this.lastLibroIdValue = id_libro

    // Trova il clientable_id e type dai data attributes della sezione righe
    let righeSection = document.querySelector('#righe_list') || document.querySelector('#documento_righe');
    let clientable_id = righeSection?.dataset.clientableId || null;
    let clientable_type = righeSection?.dataset.clientableType || null;

    // Estrai account_id dall'URL corrente (formato: /account_id/...)
    let pathParts = window.location.pathname.split('/');
    let accountId = pathParts[1];

    let url = `/${accountId}/libri/${id_libro}/get_prezzo_e_sconto`;

    // Aggiungi parametri cliente o scuola se presenti
    if (clientable_id && clientable_type === 'Cliente') {
      url += `?cliente_id=${clientable_id}`;
    } else if (clientable_id && clientable_type === 'ImportScuola') {
      url += `?scuola_id=${clientable_id}`;
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

      // Dispatch custom event with libro data (ISBN, titolo) for documento_editor
      this.element.dispatchEvent(new CustomEvent('libro:loaded', {
        bubbles: true,
        detail: {
          id: id_libro,
          codice_isbn: data.codice_isbn,
          titolo: data.titolo,
          prezzo_cents: prezzo_copertina_cents,
          prezzo_suggerito_cents: data.prezzo_suggerito_cents,
          sconto: sconto
        }
      }));

      this.quantitaTarget.focus();
      this.quantitaTarget.select();
    })
    .catch(error => {
      // Handle any errors
      console.error(error);
    });
  }
}
