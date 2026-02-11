import { Controller } from "@hotwired/stimulus"

// Su selezione libro: fetch prezzo/sconto, popola campi, dispatch evento
export default class extends Controller {
  static targets = ["combobox", "prezzo", "quantita", "sconto"]
  static values = {
    url: String,
    lastLibroId: String,
    clientableId: String,
    clientableType: String
  }

  change(event) {
    // Usa event.detail.value dal hw-combobox:selection event
    const idLibro = event.detail?.value

    if (!idLibro) {
      this.prezzoTarget.value = "0.0"
      if (this.hasScontoTarget) this.scontoTarget.value = "0.0"
      this.lastLibroIdValue = ""
      return
    }

    if (String(idLibro) === this.lastLibroIdValue) {
      this.quantitaTarget.focus()
      this.quantitaTarget.select()
      return
    }
    this.lastLibroIdValue = String(idLibro)

    let url = this.urlValue.replace("__ID__", idLibro)
    if (this.clientableIdValue && this.clientableTypeValue === "Cliente") {
      url += `?cliente_id=${this.clientableIdValue}`
    } else if (this.clientableIdValue && this.clientableTypeValue === "Scuola") {
      url += `?scuola_id=${this.clientableIdValue}`
    }

    fetch(url, { headers: { "Accept": "application/json" } })
      .then(r => r.json())
      .then(data => {
        this.prezzoTarget.value = data.prezzo_copertina_cents / 100.0
        if (this.hasScontoTarget) this.scontoTarget.value = data.sconto || 0.0

        this.element.dispatchEvent(new CustomEvent("libro:loaded", {
          bubbles: true,
          detail: {
            id: idLibro,
            codice_isbn: data.codice_isbn,
            titolo: data.titolo,
            prezzo_cents: data.prezzo_copertina_cents,
            prezzo_suggerito_cents: data.prezzo_suggerito_cents,
            sconto: data.sconto || 0
          }
        }))

        this.quantitaTarget.focus()
        this.quantitaTarget.select()
      })
      .catch(error => console.error("Error fetching prezzo:", error))
  }
}
