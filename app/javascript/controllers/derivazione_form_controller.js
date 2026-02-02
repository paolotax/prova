import { Controller } from "@hotwired/stimulus"

// Controller per gestire il form di derivazione documento
// Gestisce toggle tra "nuovo" e "esistente" e fetch del prossimo numero
export default class extends Controller {
  static targets = ["nuovoSection", "esistenteSection", "numeroField"]
  static values = {
    numeroPath: { type: String, default: "/documento_numero" }
  }

  connect() {
    // Fetch numero iniziale per la prima causale
    this.fetchNumero()
  }

  toggleModalita(event) {
    const isNuovo = event.target.value === "nuovo"

    if (this.hasNuovoSectionTarget) {
      this.nuovoSectionTarget.hidden = !isNuovo
    }
    if (this.hasEsistenteSectionTarget) {
      this.esistenteSectionTarget.hidden = isNuovo
    }
  }

  async fetchNumero() {
    const causaleSelect = this.element.querySelector("[name*='causale_id']")
    if (!causaleSelect) return

    const causaleId = causaleSelect.value
    if (!causaleId) return

    try {
      const response = await fetch(`${this.numeroPathValue}?causale=${causaleId}`, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (response.ok) {
        const data = await response.json()

        if (this.hasNumeroFieldTarget && data.numero_documento) {
          this.numeroFieldTarget.value = data.numero_documento
        }
      }
    } catch (error) {
      console.error("Errore fetch numero documento:", error)
    }
  }
}
