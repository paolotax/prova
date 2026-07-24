import { Controller } from "@hotwired/stimulus"

// Tiene l'action del form allineata alla classe selezionata: la route e nidificata
// sotto la classe (/scuole/:id/classi/:classe_id/adozioni), quindi al cambio del
// select riscriviamo l'action con l'URL della classe scelta (data-url sulle option).
export default class extends Controller {
  static targets = ["form", "select"]

  updateAction() {
    const option = this.selectTarget.selectedOptions[0]
    const url = option && option.dataset.url
    if (url) this.formTarget.action = url
  }
}
