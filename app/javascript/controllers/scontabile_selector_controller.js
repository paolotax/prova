import { Controller } from "@hotwired/stimulus"

// Mostra la select dell'entità specifica (cliente/editore/scuola)
// in base alla tipologia scelta in "Applica sconto a".
export default class extends Controller {
  static targets = ["container", "clienteSelect", "editoreSelect", "scuolaSelect"]

  connect() {
    // Initialize on page load if a value is already selected
    this.toggleScontabile()
  }

  toggleScontabile(event) {
    const selectedType = event ? event.target.value : this.element.querySelector("select").value
    const targetsByType = {
      Cliente: this.clienteSelectTarget,
      Editore: this.editoreSelectTarget,
      Scuola: this.scuolaSelectTarget
    }

    this.containerTarget.hidden = !targetsByType[selectedType]

    Object.values(targetsByType).forEach(target => {
      const active = target === targetsByType[selectedType]
      target.hidden = !active
      target.querySelector("select").disabled = !active
    })
  }
}
