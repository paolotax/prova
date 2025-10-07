import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "clienteSelect", "editoreSelect", "scuolaSelect"]

  connect() {
    // Initialize on page load if a value is already selected
    this.toggleScontabile()
  }

  toggleScontabile(event) {
    const selectedType = event ? event.target.value : this.element.querySelector("select").value

    // Hide all selects first
    this.containerTarget.classList.add("hidden")
    this.clienteSelectTarget.classList.add("hidden")
    this.editoreSelectTarget.classList.add("hidden")
    this.scuolaSelectTarget.classList.add("hidden")

    // Disable all select fields
    this.clienteSelectTarget.querySelector("select").disabled = true
    this.editoreSelectTarget.querySelector("select").disabled = true
    this.scuolaSelectTarget.querySelector("select").disabled = true

    // Show the appropriate select based on type
    if (selectedType) {
      this.containerTarget.classList.remove("hidden")

      switch(selectedType) {
        case "Cliente":
          this.clienteSelectTarget.classList.remove("hidden")
          this.clienteSelectTarget.querySelector("select").disabled = false
          break
        case "Editore":
          this.editoreSelectTarget.classList.remove("hidden")
          this.editoreSelectTarget.querySelector("select").disabled = false
          break
        case "ImportScuola":
          this.scuolaSelectTarget.classList.remove("hidden")
          this.scuolaSelectTarget.querySelector("select").disabled = false
          break
      }
    }
  }
}
