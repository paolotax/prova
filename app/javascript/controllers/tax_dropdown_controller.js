import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-dropdown"
export default class extends Controller {

  static targets = ["provincia", "regione", "grado", "tipo"];

  submit() {
    
    this.element.requestSubmit();
    
    let hprovincia   = document.getElementById("hprovincia");
    let hregione     = document.getElementById("hregione");
    let hgrado = document.getElementById("hgrado");
    let htipo = document.getElementById("htipo");
    
    let prov = this.provinciaTarget.options[this.provinciaTarget.selectedIndex].text;
    let regione = this.regioneTarget.options[this.regioneTarget.selectedIndex].text;
    let grado = this.gradoTarget.options[this.gradoTarget.selectedIndex].text;
    let tipo = this.tipoTarget.options[this.tipoTarget.selectedIndex].text;
    
    hregione.value = regione;
    hprovincia.value = prov;
    hgrado.value = grado;
    htipo.value = tipo;
  }
}
