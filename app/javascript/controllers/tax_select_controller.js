import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-select"
export default class extends Controller {

  static targets = ["provincia", "regione", "grado", "tipo", "gruppo", "editore", "navigator"];

  submit() {
    
    this.element.requestSubmit();
    
    if (this.hasRegioneTarget) {
      let hregione     = document.getElementById("hregione");
      let regione = this.regioneTarget.options[this.regioneTarget.selectedIndex].text;
      hregione.value = regione;
    }

    if (this.hasProvinciaTarget) {
      let hprovincia   = document.getElementById("hprovincia");
      let prov = this.provinciaTarget.options[this.provinciaTarget.selectedIndex].text;
      hprovincia.value = prov;
    }

    if (this.hasGradoTarget) {
      let hgrado = document.getElementById("hgrado");
      let grado = this.gradoTarget.options[this.gradoTarget.selectedIndex].value;
      hgrado.value = grado;
    }    

    if (this.hasTipoTarget) {
      let htipo = document.getElementById("htipo");
      let tipo = this.tipoTarget.options[this.tipoTarget.selectedIndex].text;
      htipo.value = tipo;
    }    

    if (this.hasGruppoTarget) {
      let hgruppo = document.getElementById("hgruppo");
      let gruppo = this.gruppoTarget.options[this.gruppoTarget.selectedIndex].text;
      hgruppo.value = gruppo;
    }

    if (this.hasEditoreTarget) {
      let heditore = document.getElementById("heditore");
      let editore = this.editoreTarget.options[this.editoreTarget.selectedIndex].value
      heditore.value = editore;
    }
  }
}
