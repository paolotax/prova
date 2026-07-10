import { Controller } from "@hotwired/stimulus"

// Nasconde dalla select le causali non pertinenti al tipo di destinatario
// selezionato (data-clientable-types vuoto = causale valida per tutti i tipi).
// La causale già selezionata resta comunque visibile.
// Nasconde inoltre il campo "Pagamento previsto" quando la causale
// selezionata non gestisce il pagamento (data-gestione-pagamento="false").
export default class extends Controller {
  static targets = [ "select", "pagamentoField" ]
  static values = { tipo: String }

  connect() {
    this.#filter()
    this.#togglePagamento()
  }

  update() {
    this.tipoValue = this.#selectedTipo()
    this.#filter()
  }

  changeCausale() {
    this.#togglePagamento()
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

  #togglePagamento() {
    if (!this.hasSelectTarget || !this.hasPagamentoFieldTarget) return

    const option = this.selectTarget.selectedOptions[0]
    const gestisce = !option || option.dataset.gestionePagamento !== "false"
    this.pagamentoFieldTarget.hidden = !gestisce
  }
}
