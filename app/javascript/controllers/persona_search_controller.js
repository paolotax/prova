import { Controller } from "@hotwired/stimulus"

// Gestisce la selezione persona dalla combobox di ricerca.
// Se assignUrl è presente, fa PATCH per associare la persona (es. referente bolla).
// Altrimenti compila il form nel dialog per aggiornare la persona.
export default class extends Controller {
  static values = { scuolaUrl: String, assignUrl: String, createUrl: String }
  static targets = ["form", "method", "cognome", "nome", "email", "cellulare", "materia", "divider", "submitLabel", "personaId"]

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
      this.fillForm(personaId)
    }
  }

  async fillForm(personaId) {
    const url = this.scuolaUrlValue.replace("__PERSONA_ID__", personaId)

    const response = await fetch(url, {
      headers: { "Accept": "application/json" }
    })

    if (!response.ok) return

    const data = await response.json()

    // Salva URL create originale al primo uso
    if (!this.hasCreateUrlValue) {
      this.createUrlValue = this.formTarget.action
    }

    // Setta l'id della persona esistente
    if (this.hasPersonaIdTarget) this.personaIdTarget.value = personaId

    // Compila i campi
    if (this.hasCognomeTarget) this.cognomeTarget.value = data.cognome || ""
    if (this.hasNomeTarget) this.nomeTarget.value = data.nome || ""
    if (this.hasEmailTarget) this.emailTarget.value = data.email || ""
    if (this.hasCellulareTarget) this.cellulareTarget.value = data.cellulare || ""
    if (this.hasMateriaTarget) this.materiaTarget.value = data.materia || ""

    // Cambia form action a update (PATCH)
    this.formTarget.action = url
    this.methodTarget.value = "patch"

    // Aggiorna UI
    if (this.hasDividerTarget) this.dividerTarget.textContent = `aggiorna ${data.cognome} ${data.nome}`
    if (this.hasSubmitLabelTarget) this.submitLabelTarget.textContent = "Aggiorna"
  }
}
