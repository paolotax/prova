import { Controller } from "@hotwired/stimulus"

// Composizione: ascolta il cambio causale e aggiorna il numero documento
// Usa l'endpoint esistente GET /documento_numero?causale=X
export default class extends Controller {
  static targets = ["numero"]
  static values = { url: String }

  change(event) {
    const causaleId = event.target.value
    if (!causaleId) return

    fetch(`${this.urlValue}?causale=${causaleId}`, {
      headers: { "Accept": "application/json" }
    })
    .then(r => r.json())
    .then(data => {
      if (this.hasNumeroTarget) {
        this.numeroTarget.value = data.numero_documento
      }
    })
    .catch(error => console.error("Error fetching numero:", error))
  }
}
