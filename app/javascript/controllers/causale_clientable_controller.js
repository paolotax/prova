import { Controller } from "@hotwired/stimulus"

// Nasconde dalla select le causali non pertinenti al tipo di destinatario
// selezionato (data-clientable-types vuoto = causale valida per tutti i tipi).
// La causale già selezionata resta comunque visibile.
export default class extends Controller {
  static targets = [ "select" ]
  static values = { tipo: String }

  connect() {
    this.#filter()
  }

  update() {
    this.tipoValue = this.#selectedTipo()
    this.#filter()
  }

  #selectedTipo() {
    const field = this.element.querySelector('input[name="documento[clientable_value]"]')
    return field?.value?.split(":")[0] || ""
  }

  #filter() {
    if (!this.hasSelectTarget) return

    for (const option of this.selectTarget.options) {
      if (!option.value) continue

      const pertinente = this.#pertinente(option)
      option.hidden = !pertinente
      option.disabled = !pertinente
    }

    for (const group of this.selectTarget.querySelectorAll("optgroup")) {
      group.hidden = ![ ...group.children ].some(option => !option.hidden)
    }
  }

  #pertinente(option) {
    if (option.selected) return true
    if (!this.tipoValue) return true

    const tipi = (option.dataset.clientableTypes || "").split(" ").filter(Boolean)
    return tipi.length === 0 || tipi.includes(this.tipoValue)
  }
}
