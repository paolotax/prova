import { Controller } from "@hotwired/stimulus"

// Gestisce la selezione persona dalla combobox di ricerca.
// Se assignUrl è presente, fa PATCH per associare la persona (es. referente bolla).
// Altrimenti naviga alla scheda persona.
export default class extends Controller {
  static values = { scuolaUrl: String, assignUrl: String }

  select(event) {
    const personaId = event.detail?.value
    if (!personaId) return

    if (this.hasAssignUrlValue && this.assignUrlValue) {
      const token = document.querySelector('meta[name="csrf-token"]')?.content
      fetch(this.assignUrlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": token,
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ persona_id: personaId })
      }).then(() => Turbo.visit(window.location.href))
    } else {
      const url = this.scuolaUrlValue.replace("__PERSONA_ID__", personaId)
      Turbo.visit(url)
    }
  }
}
