import { Controller } from "@hotwired/stimulus"

// Gestisce la selezione persona dalla combobox di ricerca.
// Naviga alla scheda persona quando si seleziona un risultato.
export default class extends Controller {
  static values = { scuolaUrl: String }

  select(event) {
    const personaId = event.detail?.value
    if (!personaId) return

    const url = this.scuolaUrlValue.replace("__PERSONA_ID__", personaId)
    Turbo.visit(url)
  }
}
